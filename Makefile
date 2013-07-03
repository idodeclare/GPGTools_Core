all: packages

packages:
	/usr/local/bin/packagesbuild installer/key.pkgproj
	/usr/local/bin/packagesbuild installer/autofix.pkgproj
	/usr/local/bin/packagesbuild installer/CheckPrivateKey.pkgproj

update:
	@git submodule foreach git pull origin master
	@git pull origin master

init:
