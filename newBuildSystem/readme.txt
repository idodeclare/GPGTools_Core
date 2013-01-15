Zum einfachen kompilieren muss nur "make" ausgeführt werden.

Folgende make Befehle sind vorhanden, in Klammern die Befehle die ebenfalls ausgeführt werden:
compile      Kompiliert wenn das Programm nicht neuer als die Source Dateien ist.
pkg-core     Erstellt das _core.pkg, wenn die Version nicht der Version des Programms entspricht. (compile)
pkg          Gleiches wie pkg-core nur für das normale pkg. (pkg-core)
dmg          Erstellt ein dmg, wenn es nicht schon vorhanden ist. (pkg)
clean        Säubert das aktuelle Projekt und führt ein clean mit Xcode aus.
clean-all    Wie clean, säubert zusätzlich alle Dependencies. (clean)
update       Aktualisiert per git pull das aktuelle Projekt und die Dependencies. (update-me)
update-me    Wie update, allerdings nur für das aktuelle Projekt.
gpg-sig      Erzeugt eine detached signature für das dmg. (dmg)
sparkle-sig  Berechnet die sparkle signature für das dmg. (smg)
signed-dmg   Kombination aus gpg-sig und sparkle-sig. (gpg-sig, sparkle-sig)


