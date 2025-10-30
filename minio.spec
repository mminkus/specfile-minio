%global tag RELEASE.2025-10-15T17-29-55Z
%global subver %(echo %{tag} | sed -e 's/[^0-9]//g')

# git fetch https://github.com/minio/minio.git refs/tags/RELEASE.2025-10-15T17-29-55Z
# git rev-list -n 1 FETCH_HEAD
%global commitid 9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a

# Custom release tag for internal builds
# Can be overridden at build time with: rpmbuild --define 'release_prefix CUSTOM'
%{!?release_prefix: %global release_prefix RELEASE}

%global miniouserhome /var/lib/minio
%global daemon_name %{name}

## Disable debug packages.
%global debug_package %{nil}

## Go related tags.
%global gobuild(o:) go build -ldflags "${LDFLAGS:-}" %{?**};
%global gopath %{_libdir}/golang
%global import_path github.com/minio/minio

Summary:        MinIO is a High Performance Object Storage released under AGPLv3.
Name:           minio
Version:        %{subver}.0.0
Release:        1
Vendor:         MinIO, Inc.
License:        GNU AGPLv3
Group:          Applications/File
Source0:        https://github.com/minio/minio/archive/%{tag}.tar.gz
Source1:        minio.service
Source2:        minio.conf
URL:            https://www.min.io/
BuildRequires:  golang >= 1.21
Requires(pre):  shadow-utils
BuildRoot:      %{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
MinIO is a High Performance Object Storage released under GNU AGPLv3.
It is API compatible with Amazon S3 cloud storage service. Use MinIO
to build high performance infrastructure for machine learning, analytics
and application data workloads.

%prep
%autosetup -p1 -n minio-%{tag}

cp %{SOURCE1} %{SOURCE2} .

%build
# setup flags like 'go run buildscripts/gen-ldflags.go' would do
tag=%{tag}
version=${tag#RELEASE.}
commitid=%{commitid}
scommitid=$(echo $commitid | cut -c1-12)
prefix=%{import_path}/cmd

# Use custom release prefix (configurable for internal builds, defaults to RELEASE)
release_tag="%{release_prefix}.$version"

LDFLAGS="\
-X $prefix.Version=$version
-X $prefix.ReleaseTag=$release_tag
-X $prefix.CommitID=$commitid
-X $prefix.ShortCommitID=$scommitid"

GO111MODULE=on CGO_ENABLED=0 \
go build -v -o %{name} -tags kqueue -ldflags "$LDFLAGS" %{import_path}

%install
install -d %{buildroot}%{_sbindir}
install -p %{name} %{buildroot}%{_sbindir}

install -D -p -m 0644 minio.service %{buildroot}/usr/lib/systemd/system/%{daemon_name}.service
install -D -p -m 0644 minio.conf %{buildroot}%{_sysconfdir}/default/%{daemon_name}

%clean
rm -rf $RPM_BUILD_ROOT

%pre
/usr/sbin/groupadd -r minio-user >/dev/null 2>&1 || :
/usr/sbin/useradd -M -r -g minio-user -d %{miniouserhome} -s /sbin/nologin \
  -c "MinIO Cloud Storage Server" minio-user >/dev/null 2>&1 || :
 
%post
%systemd_post %{daemon_name}.service

%preun
%systemd_preun %{daemon_name}.service

%postun
%systemd_postun_with_restart %{daemon_name}.service

%files
%defattr(644,root,root,755)
%doc README.md
%attr(755,root,root) %{_sbindir}/minio
/usr/lib/systemd/system/%{daemon_name}.service
%config(noreplace) %{_sysconfdir}/default/%{daemon_name}

%changelog
* Thu Oct 30 2025 Martin Minkus <martin.minkus@gmail.com> - 20251015172955.0.0-1
- Update to RELEASE.2025-10-15T17-29-55Z (includes critical security fixes)
- Add configurable release_prefix for custom branding (default: RELEASE)
- Change config location from /etc/sysconfig to /etc/default (matches upstream)
- Change service user from minio to minio-user (matches upstream)
- Update systemd service to match official MinIO unit file

* Tue Mar 17 2020 Davide Madrisan <davide.madrisan@gmail.com> - 0.0.20200314022158-1
- Packaging of MinIO based on the specfile found in the git repository
