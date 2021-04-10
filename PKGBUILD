# Maintainer: Derek Taylor (DistroTube) <derek@distrotube.com>
pkgname=dwt-dmscripts
_pkgname=dmscripts
pkgver=1.0.r80.4d9cd0c
pkgrel=1
pkgdesc="collection of dmenu scripts"
arch=('any')
url="https://gitlab.com/dwt1/dmscripts.git"
license=('GPL3')
depends=(dmenu xclip findutils zenity xdotool xorg-xrandr )
groups=()
makedepends=()
checkdepends=()
optdepends=(
  'emacs: editor for dmconf '
  'slock: used by dmlogout' 
  'libnotify: used by dmlogout' 
  'qutebrowser: used by dmqute'
  'reddio: used by dmred' 
  )
provides=(dmscripts)
conflicts=(dmscripts)
replaces=()
backup=()
options=()
source=("git+$url")
noextract=()
md5sums=('SKIP')
validpgpkeys=()

pkgver() {
  cd "${_pkgname}"
  printf "1.0.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}


package() {
  cd ${_pkgname}
  install -Dm755 dman -t "${pkgdir}/usr/bin"
  install -Dm755 dmconf -t "${pkgdir}/usr/bin"
  install -Dm755 dmkill -t "${pkgdir}/usr/bin"
  install -Dm755 dmqute -t "${pkgdir}/usr/bin"
  install -Dm755 dmred -t "${pkgdir}/usr/bin"
  install -Dm755 dmscrot -t "${pkgdir}/usr/bin"
  install -Dm755 dmsearch -t "${pkgdir}/usr/bin"
}
