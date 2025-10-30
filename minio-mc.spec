%global tag RELEASE.2025-08-13T08-35-41Z
%global subver %(echo %{tag} | sed -e 's/[^0-9]//g')

# git fetch https://github.com/minio/mc.git refs/tags/RELEASE.2025-08-13T08-35-41Z
# git rev-list -n 1 FETCH_HEAD
%global commitid 7394ce0dd2a80935aded936b09fa12cbb3cb8096

# Custom release tag for internal builds
# Can be overridden at build time with: rpmbuild --define 'release_prefix CUSTOM'
%{!?release_prefix: %global release_prefix RELEASE}

## Disable debug packages.
%global debug_package %{nil}

## Go related tags.
%global gobuild(o:) go build -ldflags "${LDFLAGS:-}" %{?**};
%global gopath %{_libdir}/golang
%global import_path github.com/minio/mc

Summary:        MinIO Client for cloud storage and filesystems
Name:           mcli
Version:        %{subver}.0.0
Release:        1
Vendor:         MinIO, Inc.
License:        GNU AGPLv3
Group:          Applications/File
Source0:        https://github.com/minio/mc/archive/%{tag}.tar.gz
URL:            https://www.min.io/
BuildRequires:  golang >= 1.21
Requires(pre):  shadow-utils
BuildRoot:      %{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
MinIO Client (mc) provides a modern alternative to UNIX commands like
ls, cat, cp, mirror, diff etc. It supports filesystems and Amazon S3
compatible cloud storage service (AWS Signature v2 and v4).

%prep
%autosetup -p1 -n mc-%{tag}

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
go build -v -o mcli -tags kqueue -ldflags "$LDFLAGS" %{import_path}

%install
install -d %{buildroot}%{_bindir}
install -p mcli %{buildroot}%{_bindir}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%doc README.md
%attr(755,root,root) %{_bindir}/mcli

%changelog
* Thu Oct 30 2025 Martin Minkus <martin.minkus@gmail.com> - 20250813083541.0.0-1
- Update to RELEASE.2025-08-13T08-35-41Z
- Rename package and binary to mcli (matches official naming, avoids Midnight Commander conflict)
- Add configurable release_prefix for custom branding (default: RELEASE)

* Fri Mar 20 2020 Davide Madrisan <davide.madrisan@gmail.com> - 0.0.20200314T012337Z-1
- First build
