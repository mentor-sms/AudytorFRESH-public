# AudytorFRESH-public

Temat: AudytorFRESH/installer4lab

# installer4lab (1)

1. rozpakuj *exe4installer.zip* > *exe4installer.exe*
2. Otwiera sie za pierwszym razem dluzsza chwile (git clone), czekaj.
3. Zminimalizuj.

Pliki wewnetrzne: *installer4lab.exe\run*

Pliki uzytkownika: *%userprofile%\Mentor*

*Mentor\root4rpi* - synchronizacja z */* (root). Dowolnie modyfikuj ten katalog. Sciezki zabronione:
```
home/pi/*
etc/ssh/ssh_host_rsa_key
etc/ssh/ssh_host_rsa_key.pub
usr/local/bin/student4lab
usr/lib/libmentor4lab*
```

*Mentor\home4copy* - synchronizacja z */home/pi*. Dowolnie modyfikuj ten katalog. Dodatkowe pliki w kroku (2). Sciezki zabronione:
```
copy4prepare.sh
.profile
.ssh/known_hosts
.ssh/authorized_keys
```
*.mentor/known_keys/\*.pub* - extra klucze SSH dla *known_hosts/authorized_keys*

*.mentor/profile.sh*, *.mentor/prepare4lab.run* - zamiast *.profile*

__jezeli usunales lub dodales pliki: Przeladuj__

Nie zmieniaj nazw plikow *\*.marker* w dialogach.
Zapisz plik *nazwa.marker* w miejsciu gdzie ma zostac utworzony katalog *nazwa*.

# SD

1. https://downloads.raspberrypi.org/imager/imager_latest.exe
2. Storage: SD card,
Device: Raspberry Pi 4,
OS: Raspberry Pi OS (64-bit, wersja Recommended),
Next.
3. Dialog: Edit settings.
4. GENERAL. Set username: `pi`, password: dowolne, Configure wireless LAN: NIE, Set locale settings: Europe/Warsaw.
5. SERVICES. Enable SSH: TAK, Allow public-key authentication only: TAK, Set authorized key for 'pi': zawartosc *Mentor\ssh4win\id_ed25519.pub*.
6. OPTIONS. Eject media when finished: YES (nie modyfikuj bootfs).
7. SAVE.
8. Dialog: YES, YES.
9. CONTINUE, zamknij.
10. SD > RPI.

# install4lab (2)

1. Przygotuj pendrive FAT32
2. Konfiguruj SSH: TAK (pierwsze uruchomienie, nowy pulpit/instalacja w sieci, blad bezpieczenstwa), Dalej (Test).
3. aaa.bbb.ccc.ddd:port - teacher4lab IP (port dowolny).
4. Kopiuj student4lab zdalnie: NIE, student4lab > pen (przy aktualizacji: TAK, student4lab > *Mentor\home4copy*).
5. Generuj skrypt instalacji, wybierz __katalog glowny__ pendrive (przy aktualizacji: katalog Mentor).
6. Opcjonalnie zedytuj *USB\home4copy* > */home/pi* (dla kroku: RPI).
7. Bezpiecznie wysun urzadzenie i odczekaj 5 sekund, bo naprawde... :)

# RPI

1x USB: klawiatura, 2x USB: klawiatura + pendrive.
Przygotowanie:
```bash
sudo apt update
sudo apt upgrade
sudo apt full-upgrade -y
#sudo apt install dos2unix
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
```
Instalacja 1x USB (przygotuj pendrive do podmiany z klawiatura zgodnie z instrukcja na ekranie):
```bash
sudo ./copy4prepare.sh --job release
```
Instalacja 2x USB:
```bash
sudo ./copy4prepare.sh --timeout 0 --job release
```
Postepuj zgodnie z instrukcjami na ekranie. Po komunikacje o ponownym uruchomieniu w sieci docelowej:
```bash
poweroff
```
# ISO
1. Sklonuj SD na karty dla pozostalych pulpitow.
2. Skonfiguruj ostatecznie siec.
3. Wlacz pulpity. Uruchomia sie ponownie kilka razy, konczac konfiguracje.
4. Oczekuj komunikatu "Mentor wita!" u gory ekranu na kazdym z pulpitow. Jezeli tak nie jest - cos poszlo nie tak.

# install4lab (3)

1. Szukaj pulpitow: TAK, Konfiguruj backdoor SSH: NIE.
2. aaa.bbb.ccc.xxx-yyy - aaa.bbb.ccc prefix IP pulpitow + zakres koncowek (wyswietlone na RPI, xxx-xxx dla jednego pulpitu, __bezpiecznie 2-254__).
3. Ilosc pulpitow: zostanie nadpisane przez Test.
4. Test. 
5. Ok? Dalej.
6. Force reinstall: NIE, Buduj zdalnie: NIE. Zmiana konfiguracji: TAK, NIE. Aktualizacja aplikacji: NIE, TAK.