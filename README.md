# AudytorFRESH-public

Temat: AudytorFRESH/installer4lab

# installer4lab (1)

1. rozpakuj *exe4installer.zip* > *exe4installer.exe*
2. Otwiera sie za pierwszym razem dluzsza chwile (git clone), czekaj.
3. Zminimalizuj.

Pliki wewnetrzne: *installer4lab.exe\run*

Pliki uzytkownika: *%userprofile%\Mentor*

Nie zmieniaj nazw plikow *\*.marker* w dialogach.
Zapisz plik *nazwa.marker* w miejsciu gdzie ma zostac utworzony katalog *nazwa*.
Otworz plik *nazwa.marker* w katalogu *nazwa* ktory chcesz wskazac (utworz recznie by oznaczyc katalog jako wybieralny).

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

# install4lab (2)

1. Przygotuj pendrive FAT32
2. Konfiguruj SSH: TAK (pierwsze uruchomienie, nowy pulpit/instalacja w sieci, blad bezpieczenstwa), Dalej (Test).
3. aaa.bbb.ccc.ddd:port - teacher4lab IP (port dowolny).
4. Kopiuj student4lab zdalnie (dlugo!): NIE, student4lab > pen (przy aktualizacji: TAK, student4lab > *Mentor\home4copy*).
5. Generuj skrypt instalacji, wybierz __katalog glowny__ pendrive (przy aktualizacji: katalog Mentor).
6. Opcjonalnie zedytuj *USB\home4copy* > */home/pi* (krok: RPI).
7. Bezpiecznie wysun urzadzenie i odczekaj 10 sekund, bo naprawde... :)

# RPI

1x USB: klawiatura, 2x USB: klawiatura + pendrive.
Przygotowanie:
```bash
sudo apt update
sudo apt full-upgrade
sudo apt install dos2unix
sudo apt autoremove
sudo apt clean
reboot
cd ~
curl -L -o copy4prepare.sh https://tinyurl.com/copy4prepare
dos2unix -f -k copy4prepare.sh
chmod +x copy4prepare.sh
```
Pomoc (np. gdy `lsblk` zwraca */dev/sdb*):
```bash
./copy4prepare.sh --help
````
Instalacja 1x USB (przygotuj pendrive do podmiany na klawiature,:
```bash
sudo ./copy4prepare.sh --job release
```
Instalacja 2x USB:
```bash
sudo ./copy4prepare.sh --timeout 0 --job release
```
~~~~