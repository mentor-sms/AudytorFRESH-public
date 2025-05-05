# AudytorFRESH-public

Temat: AudytorFRESH/installer4lab

# installer4lab

1. rozpakuj *exe4installer.zip* > *exe4installer.exe*
2. Otwiera sie za pierwszym razem dluzsza chwile (git clone), czekaj.
3. Konfiguracja: domyslne *Mentor* w katalogu domowym, OK.
4. Zminimalizuj.

# SD

1. https://downloads.raspberrypi.org/imager/imager_latest.exe
2. Storage: SD card,
Device: Raspberry Pi 4,
OS: Raspberry Pi OS (other)/Raspberry Pi OS Lite (64-bit),
Next.
3. Dialog: Edit settings.
4. GENERAL. Set username: `pi`, password: dowolne, Configure wireless LAN: NIE, Set locale settings: Europe/Warsaw.
5. SERVICES. Enable SSH: TAK, Allow public-key authentication only: TAK, Set authorized key for 'pi': zawartosc *Mentor\ssh4win\id_ed25519.pub*.
6. OPTIONS. Eject media when finished: YES.
7. SAVE.
8. Dialog: YES, YES.
9. CONTINUE, zamknij.
10. SD > RPI.

# install4lab

1. FAT32 USB
2. Uaktualnij, Przeladuj, Konfiguruj SSH (pierwsze uruchomienie, nowy pulpit/instalacja w sieci, blad bezpieczenstwa), Dalej (Test).
3. aaa.bbb.ccc.ddd:port - teacher4lab IP.
4. Generuj skrypt instalacji, wybierz __katalog glowny__ pendrive i nie zmieniaj nazwy pliku.
5. Bezpiecznie wysun urzadzenie. :)

# RPI

```bash
$ sudo apt update
$ sudo apt full-upgrade
$ sudo apt install dos2unix
$ sudo apt autoremove
$ sudo apt clean
$ reboot
$ cd ~
$ curl -L -o copy4prepare.sh https://tinyurl.com/copy4prepare
$ dos2unix -f -k copy4prepare.sh
$ chmod +x copy4prepare.sh
$ ./copy4prepare.sh --help
$ sudo ./copy4prepare.sh release
```
