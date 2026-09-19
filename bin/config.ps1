@{
    repositories = @(
        "ScoopInstaller/Main",
        "ScoopInstaller/Extras",
        "ScoopInstaller/Versions",
        "ScoopInstaller/Nonportable",
        "ScoopInstaller/Java",
        "ScoopInstaller/PHP",
        "kodybrown/scoop-nirsoft",
        "matthewjberger/scoop-nerd-fonts",
        "Calinou/scoop-games",
        "niheaven/scoop-sysinternals",
        # charmbracelet
        "charmbracelet/scoop-bucket",
        # My repo
        "nostalume/winspec",
        "nostalume/spx",
        "nostalume/shed"
    )

    proxies      = @{
        Github   = "https://gh-proxy.org"
        Tsinghua = "mirrors.tuna.tsinghua.edu.cn"
        Nju      = "mirrors.nju.edu.cn"
        Ustc     = "mirrors.ustc.edu.cn"
    }

    rules        = @(
        @{
            description = "Proxy: GitHub Releases Download"
            find        = '(https?://github\.com/.+/releases/.*download)'
            replace     = '${Github}/$1'
            enabled     = $true
        },
        @{
            description = "Proxy: GitHub Archive"
            find        = '(https?://github\.com/.+/archive/)'
            replace     = '${Github}/$1'
            enabled     = $true
        },
        @{
            description = "Proxy: GitHub Gists"
            find        = '(https?://gist\.github\.com/.+/)'
            replace     = '${Github}/$1'
            enabled     = $true
        },
        @{
            description = "Proxy: GitHub Raw (raw.githubusercontent.com)"
            find        = '(https?://raw\.githubusercontent\.com)'
            replace     = '${Github}/$1'
            enabled     = $true
        },
        @{
            description = "Proxy: GitHub Raw (github.com/user/repo/raw/)"
            find        = '(https?://github\.com/.+/raw/)'
            replace     = '${Github}/$1'
            enabled     = $true
        },
        @{
            description = "Proxy: DBeaver (to GitHub Releases)"
            find        = 'https?://dbeaver\.io/files/([\d\.]+)/'
            replace     = '${Github}/https://github.com/dbeaver/dbeaver/releases/download/$1/'
            enabled     = $true
        },
        @{
            description = "Proxy: FastCopy (to GitHub Raw)"
            find        = 'https?://fastcopy\.jp/archive'
            replace     = '${Github}/https://raw.githubusercontent.com/FastCopyLab/FastCopyDist2/main'
            enabled     = $true
        },
        @{
            description = "Proxy: OBS Studio (cdn-fastly) to GitHub Releases"
            find        = 'https?://cdn-fastly\.obsproject\.com/downloads/OBS-Studio-(.+)-Windows'
            replace     = '${Github}/https://github.com/obsproject/obs-studio/releases/download/$1/OBS-Studio-$1-Windows'
            enabled     = $true
        },
        @{
            description = "Proxy: OBS Studio 2.7 (cdn-fastly) to GitHub Releases"
            find        = 'https?://cdn-fastly\.obsproject\.com/downloads/OBS-Studio-(.+)-Full'
            replace     = '${Github}/https://github.com/obsproject/obs-studio/releases/download/$1/OBS-Studio-$1-Full'
            enabled     = $true
        },
        @{
            description = "Proxy: Strawberry Music Player to GitHub Releases"
            find        = 'https?://files\.jkvinge\.net/packages/strawberry/StrawberrySetup-(.+)-mingw-x'
            replace     = '${Github}/https://github.com/strawberrymusicplayer/strawberry/releases/download/$1/StrawberrySetup-$1-mingw-x'
            enabled     = $true
        },
        @{
            description = "Proxy: 7-Zip (to GitHub Releases)"
            find        = 'https?://www\.7-zip\.org/a/7z(\d{2})(\d{2})'
            replace     = '${Github}/https://github.com/ip7z/7zip/releases/download/$1.$2/7z$1$2'
            enabled     = $true
        },
        @{
            description = "Proxy: 7-Zip 7zr.exe (to GitHub Releases)"
            find        = 'https?://www\.7-zip\.org/a/7zr\.exe'
            replace     = '${Github}/https://github.com/ip7z/7zip/releases/download/24.09/7zr.exe'
            enabled     = $true
        },
        @{
            description = "Mirror: Blender"
            find        = 'download\.blender\.org'
            replace     = '${Tsinghua}/blender'
            enabled     = $true
        },
        @{
            description = "Mirror: Cygwin"
            find        = '(https?://)(?:www\.)?cygwin\.com/'
            replace     = '${1}${Tsinghua}/cygwin/'
            enabled     = $true
        },
        @{
            description = "Mirror: GIMP"
            find        = 'download\.gimp\.org/mirror/pub'
            replace     = '${Nju}/gimp'
            enabled     = $true
        },
        @{
            description = "Mirror: Go"
            find        = 'dl\.google\.com/go'
            replace     = '${Nju}/golang'
            enabled     = $true
        },
        @{
            description = "Mirror: Gradle"
            find        = 'services\.gradle\.org/distributions'
            replace     = '${Nju}/gradle'
            enabled     = $true
        },
        @{
            description = "Mirror: Inkscape"
            find        = 'media\.inkscape\.org/dl/resources/file'
            replace     = '${Nju}/inkscape'
            enabled     = $true
        },
        @{
            description = "Mirror: Kodi"
            find        = 'mirrors\.kodi\.tv'
            replace     = '${Tsinghua}/kodi'
            enabled     = $true
        },
        @{
            description = "Mirror: LaTeX, MiKTeX (CTAN)"
            find        = '(miktex\.org/download/ctan)|(mirrors.+/CTAN)'
            replace     = '${Tsinghua}/CTAN'
            enabled     = $true
        },
        @{
            description = "Mirror: Node"
            find        = 'nodejs\.org/dist'
            replace     = '${Ustc}/node'
            enabled     = $true
        },
        @{
            description = "Mirror: Python"
            find        = 'www\.python\.org/ftp/python'
            replace     = '${Nju}/python'
            enabled     = $true
        },
        @{
            description = "Mirror: Vim"
            find        = 'ftp\.nluug\.nl/pub/vim/pc'
            replace     = '${Nju}/vim/pc'
            enabled     = $true
        },
        @{
            description = "Mirror: VirtualBox"
            find        = 'download\.virtualbox\.org/virtualbox'
            replace     = '${Tsinghua}/virtualbox'
            enabled     = $true
        },
        @{
            description = "Mirror: VLC"
            find        = 'download\.videolan\.org/pub'
            replace     = '${Tsinghua}/videolan-ftp'
            enabled     = $true
        },
        @{
            description = "Mirror: Wireshark"
            find        = 'www\.wireshark\.org/download'
            replace     = '${Tsinghua}/wireshark'
            enabled     = $true
        },
        @{
            description = "Mirror: Lunacy (Icons8)"
            find        = 'lun-eu\.icons8\.com/s/'
            replace     = 'lcdn.icons8.com/'
            enabled     = $true
        },
        @{
            description = "Mirror: Tor Browser, Tor"
            find        = 'archive\.torproject\.org/tor-package-archive'
            replace     = 'tor.calyxinstitute.org/dist'
            enabled     = $true
        },
        @{
            description = "Mirror: Typora"
            find        = 'download\.typora\.io'
            replace     = 'downloads.typoraio.cn'
            enabled     = $true
        }
    )

    # Post-processing: Fix specific bucket issues that may be fixed upstream eventually
    postprocess  = @(
        @{
            description = "charmbracelet: Rename .json to wishlist.json"
            action      = "rename"
            from        = ".json"
            to          = "wishlist.json"
            enabled     = $true
        }
    )
}
