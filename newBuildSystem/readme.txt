Zum einfachen kompilieren muss nur "make" ausgeführt werden.

Folgende make Befehle sind vorhanden, in Klammern die Befehle die ebenfalls ausgeführt werden:
compile      Kompiliert wenn das Programm nicht neuer als die Source Dateien ist.
pkg-core     Erstellt das _core.pkg, wenn die Version nicht der Version des Programms entspricht. (compile)
pkg          Gleiches wie pkg-core nur für das normale pkg. (pkg-core)
dmg          Erstellt ein dmg, wenn es nicht schon vorhanden ist. (pkg)
clean        Säubert das aktuelle Projekt und führt ein clean mit Xcode aus.
clean-pkg    Entfernt die pkgs.
clean-all    Wie clean, säubert zusätzlich alle Dependencies. (clean)
update       Aktualisiert per git pull das aktuelle Projekt und die Dependencies. (update-me)
update-me    Wie update, allerdings nur für das aktuelle Projekt.
gpg-sig      Erzeugt eine detached signature für das dmg. (dmg)
sparkle-sig  Berechnet die sparkle signature für das dmg. (smg)
signed-dmg   Kombination aus gpg-sig und sparkle-sig. (gpg-sig, sparkle-sig)

Umgebungsvariablen:
CODE_SIGN    Soll der Code signiert werden. (default=0)
PKG_SIGN     Sollen die pkgs signiert werden. (default=0)

=========================================================================================================
Makefile.config:

# Einträge die nicht als Required makiert sind, sind optional.
# Einträge die mit Default makiert sind, werden normalerweise richtig gesetzt.

name="GPGServices"  # Required
appName="GPGServices.service"  # Required

pkgProj_dir="Installer"  # Default
pkgProj_corename="GPGServices_Core.pkgproj"  # Array, Default
pkgCoreName="GPGServices_Core.pkg"  # Array, Default
pkgProj_name="GPGServices.pkgproj"  # Array, Default
pkgName="GPGServices.pkg"  # Array, Default

rmName="Uninstall.app"

imgBackground="Installer/background_dmg.png"
localizeDir="Installer/localized"
volumeName="GPG Keychain Access.localized"  # Default
volumeLayout="Installer/DS_Store"
pkgPos="290, 220"

sshKeyname="Sparkle GPGServices - Private key"

unset REVISION PRERELEASE  # Required
MAJOR=1  # Required
MINOR=7  # Required
#REVISION=1
#PRERELEASE=b8

source "$(dirname "${BASH_SOURCE[0]}")/Dependencies/GPGTools_Core/newBuildSystem/versioning.sh"  # Required

# Unübliche Einträge: pkgPath, dmgName, dmgPath, infoPlist

=========================================================================================================
*.pkgproj:

Immer ein NAME.pkgproj und mindestens ein NAME_Core.pkgroj, weitere *_Core.pkgroj tragen den Namen der Komponente, z.B. Libmacgpg_core und LibmacgpgXPC_core.

*_Core.pkgroj: raw-package, enhält komplette Komponente, ohne Abhängigkeiten; z.B. GPGMail ohne Libmacgpg.
NAME.pkgproj: Enthält NAME_Core.pkg und alle weiteren *_Core.pkg. Enhält KEINEN eigene Payload!

In den pkgproj Dateien müssen alle Pfade relativ zu build UND Installer sein! (Beispiel: Original Pfad "Installer/background.png", Pfad in der Datei "../Installer/background.png")

=========================================================================================================

Jenkins:

security unlock-keychain -p "Passwort" "Pfad zum Keychain"
CODE_SIGN=1 make compile

PKG_SIGN=0 make dmg

./Dependencies/GPGTools_Core/newBuildSystem/bb_deploy_dmg.sh /GPGTools/public/nightlies.gpgtools.org



