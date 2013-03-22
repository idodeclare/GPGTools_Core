all: dmg

update:
	@git submodule foreach git pull origin master
	@git pull origin master

compile: dmg

dmg:
	/usr/local/bin/packagesbuild installer/key.pkgproj
	/usr/local/bin/packagesbuild installer/autofix.pkgproj

test: dmg

deploy:
	@echo "Nothing to deploy."

init:
