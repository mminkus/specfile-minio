%global tag v1.7.6
%global subver 176

# git fetch https://github.com/minio/object-browser.git refs/tags/v1.7.6
# git rev-list -n 1 FETCH_HEAD
%global commitid f4a08fc0af8f776aa667677fb943aad137808f7c

# Custom release tag for internal builds
# Can be overridden at build time with: rpmbuild --define 'release_prefix CUSTOM'
%{!?release_prefix: %global release_prefix RELEASE}

%global consolehome /var/lib/minio-console
%global daemon_name %{name}

## Disable debug packages.
%global debug_package %{nil}

## Go related tags.
%global import_path github.com/minio/object-browser

Summary:        MinIO Console (Object Browser)
Name:           minio-console
Version:        1.7.6
Release:        1
Vendor:         MinIO, Inc.
License:        AGPL-3.0-only
Group:          Applications/File
Source0:        https://github.com/minio/object-browser/archive/refs/tags/%{tag}.tar.gz
Source1:        minio-console.service
Source2:        minio-console.conf
URL:            https://github.com/minio/object-browser
BuildRequires:  golang >= 1.21
BuildRequires:  nodejs >= 18
BuildRequires:  make
Requires(pre):  shadow-utils
BuildRoot:      %{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
MinIO Console (Object Browser) built from source. A single Go binary that serves the
full React-based UI and backend API for managing MinIO.

This RPM installs:
- /usr/bin/minio-console            (the binary)
- /usr/lib/systemd/system/minio-console.service
- /etc/default/minio-console        (EnvironmentFile with CONSOLE_OPTS)

%prep
%autosetup -p1 -n object-browser-1.7.6

cp %{SOURCE1} %{SOURCE2} .

%build
# Build frontend assets
cd web-app
yarn install
yarn build
cd ..

# Build Go binary with embedded frontend
make console

%install
install -d %{buildroot}%{_bindir}
install -p console %{buildroot}%{_bindir}/minio-console

install -D -p -m 0644 minio-console.service %{buildroot}/usr/lib/systemd/system/%{daemon_name}.service
install -D -p -m 0644 minio-console.conf %{buildroot}%{_sysconfdir}/default/%{daemon_name}

# Create working directory
install -d %{buildroot}%{_sharedstatedir}/minio-console

%clean
rm -rf $RPM_BUILD_ROOT

%pre
/usr/sbin/groupadd -r minio-user >/dev/null 2>&1 || :
/usr/sbin/useradd -M -r -g minio-user -d %{miniouserhome} -s /sbin/nologin \
  -c "MinIO User" minio-user >/dev/null 2>&1 || :

%post
%systemd_post %{daemon_name}.service

%preun
%systemd_preun %{daemon_name}.service

%postun
%systemd_postun_with_restart %{daemon_name}.service

%files
%defattr(644,root,root,755)
%doc README.md
%attr(755,root,root) %{_bindir}/minio-console
/usr/lib/systemd/system/%{daemon_name}.service
%config(noreplace) %{_sysconfdir}/default/%{daemon_name}
%dir %attr(0750,minio-user,minio-user) %{_sharedstatedir}/minio-console

%changelog
* Thu Oct 30 2025 Martin Minkus <martin.minkus@gmail.com> - 1.176-1
- Initial package for MinIO Console (Object Browser) v1.7.6
- Using object-browser before features were removed in community edition
- Add configurable release_prefix for custom branding (default: RELEASE)
- Uses minio-user for service account (matches MinIO server)
- Includes systemd service and configuration file
