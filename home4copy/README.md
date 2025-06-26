# AudytorFRESH-public

Temat: AudytorFRESH/installer4lab

# installer4lab (1)

1. rozpakuj *exe4installer.zip* > uruchom *exe4installer.exe*
2. Zminimalizuj.

* Pliki wewnetrzne: `[katalog z installer4lab.exe]\run` (pliki inne niz ponizej zostaną zignorowane przez aplikację):

`git_exe.txt` - polecenie w PATH, lub sciezka do `git.exe`

`ssh_exe.txt` - polecenie w PATH, lub sciezka do `ssh.exe`

`id_repo_private[.pub]` - klucz do repozytorium AudytorFRESH-private

`id_repo_config[.pub]` - klucz do repozytorium AudytorFRESH-private

`win_chown.bat` - skrypt przyznawania uprawnien dla plikow SSH na Windows (nie modyfikuj użycia!)

`source4rpi/` - katalog na aplikacje i biblioteki, automatyczna instalacja projektow CMake

* Pliki uzytkownika: `%userprofile%\Mentor`:

Komentarze funkcyjne:

```bash

#4lab>on linia_zostanie_odkomentowana
ta_linia_zostanie_zakomentowana #4lab>off

# przyklad: Mentor\etc\dhcpcd.conf
```

UWAGA na nieopisane komentarze fukncyjne: ` #4lab>var`, `#4lab>file `, `#4lab>sshkey `, `#4lab>list `, `#4lab>file `

- `Mentor\root4rpi` - Dowolnie modyfikuj ten katalog. Synchronizacja z `/` (root). `~` to `home/pi`.

`boot\cmdline.txt` - konfiguracja rozruchowa rpi, plik zostanie automatycznie uzupelniony o argument `root=` z pliku
dotychczasowego

`boot\config.txt` - glowny plik konfiguracyjny rpi

`etc\systemd\journald.conf` - logi systemu

`etc\logrotate.d\student4lab` - logi student4lab

`etc\speech-dispatcher\{speechd.conf, clients\qt-speech.conf, modules\espeak-ng.conf}` - konfiguracja syntezy mowy

`~\.config\pulse\daemon.conf` - konfiguracja PulseAudio

`~\systemd\user\speech-dispather-qt.service` - rozruch syntezy mowy

`etc\ssh\ssh_config` - konfiguracja klienta SSH (pulpit -> nauczyciel)

`etc\ssh\sshd_config` - konfiguracja serwera SSH (nauczyciel -> pulpit)

`~\.ssh\id_rsa[.pub]` - klucz SSH do komunikacji pulpitu z nauczycielem

`etc\ssh\ssh_host_rsa_key[.pub]` - zawsze taki jak `id_rsa[.pub]`

`~\.mentor\known_keys\*.pub` - generacja `/home/pi/.ssh/{known_hosts, authorized_keys}` (+ `id_rsa[.pub]`,
`ssh4win\id_ed25519[.pub]`)

`etc\dhcpcd.conf` - konfiguracja klienta DHCP

`etc\wpa_supplicant\wpa_supplicant.conf` - konfiguracja WiFi

`~\.mentor\eglfs.json` - konfiguracja EGLFS (alternatywa dla X11, nie suplementacja!)

`~\.mentor\profile.txt` - kontynuacja `/etc/skel/.profile`, modyfikuj zamiast `/home/pi/.profile`

`~\.mentor\student4lab.env` - eksport globalnych zmiennych systemowych

`~\systemd\user\student4lab.service` - rozruch student4lab

`Mentor\home4copy` - synchronizacja z `~` dla skryptu `copy4prepare.sh`.
Modyfikuj dowolnie pliki znajdujace sie w tym katalogu, ale nowe dodawaj do `Mentor\root4rpi\~`!

`home4copy\copy4prepare.sh` - skrypt kopiujacy `prepare4lab.sh` i przygotowujacy do instalacji
`~\.mentor\prepare4lab.{sh, run}` - pliki installer4lab

Pliki generowane automatycznie (zmiany uzytkownika zostana zignorowane!):

```bash

.ssh/known_hosts
.ssh/authorized_keys
```

`.mentor/known_keys/*.pub` - extra klucze SSH dla `~/.ssh/{known_hosts, authorized_keys}` (+ `id_rsa[.pub]`, +
`id_ed25519[.pub]`)

`.mentor/profile.txt`, `.mentor/prepare4lab.run` - zamiast `.profile`

__jezeli usunales lub dodales pliki: Przeladuj__

Nie zmieniaj nazw plikow `*.lab.{marker, directory}` w dialogach.
Zapisz plik `nazwa.lab.marker` w miejsciu gdzie ma zostac utworzony katalog `nazwa`.

# SD

1. https://downloads.raspberrypi.org/imager/imager_latest.exe
2. Storage: SD card,
			Device: Raspberry Pi 4,
			OS: Raspberry Pi OS (64-bit, wersja Recommended),
			Next.
3. Dialog: Edit settings. Konfiguracja w katalogu SEEME:
			GENERAL. Set username: `pi`, password: dowolne, Configure wireless LAN: NIE, Set locale settings: Europe/Warsaw.
			SERVICES. Enable SSH: TAK, Allow public-key authentication only: TAK, Set authorized key for 'pi': zawartosc
			`id_maniek.pub`.
4. OPTIONS. Eject media when finished: YES (nie modyfikuj bootfs).
5. SAVE.
6. Dialog: YES, YES.
7. CONTINUE, zamknij.
8. Upewnij sie, ze bezpiecznie usunieto bootfs.
9. SD > RPI.

# install4lab (2)

1. Przygotuj czysty pendrive FAT32, opcjonalnie nazwij patrycje docelowa np. `audytor`
2. Konfiguruj SSH: TAK (pierwsze uruchomienie, nowy pulpit/instalacja w sieci, blad bezpieczenstwa), Dalej (Test).
3. aaa.bbb.ccc.ddd:port - teacher4lab IP (port dowolny).
4. Kopiuj student4lab zdalnie: NIE, student4lab zostanie zapisany na pendrive (przy aktualizacji: TAK, student4lab
			zostanie zapisany do `Mentor\home4copy`).
5. Generuj skrypt instalacji, wybierz __katalog glowny__ pendrive (przy aktualizacji: katalog `%userprofile%\Mentor`).
6. Opcjonalnie zedytuj `USB\home4copy` > `/home/pi` (dla kroku: RPI).
7. Bezpiecznie usun urzadzenie.

# RPI

1x USB: klawiatura, 2x USB: klawiatura + pendrive.
Przygotowanie:

```bash

sudo apt update
sudo apt upgrade
sudo apt full-upgrade -y
sudo apt autoremove
sudo apt clean
reboot
```

__copy4prepare__

Bezposrednio z repozytorium AudytorFRESH-public:

```bash

cd ~
curl -L -o copy4prepare.sh https://tinyurl.com/copy4prepare
dos2unix -f -k copy4prepare.sh
chmod +x copy4prepare.sh
```

Pomoc i sciezka do skryptu:
```bash

./copy4prepare.sh
```

__GUI__

lub gdy usb juz zamontowano:
```bash

lsblk
```
`/dev/sda` -> `/media/pi/audytor`

Pomoc i sciezka do skryptu:
```bash

/media/pi/audytor/home4copy/copy4prepare.sh
```

__Instalacja__

```bash

sudo copy4prepare.sh install [--timeout 0]
```
`timeout 0` tylko gdy klawiatura i pendrive podlaczone sa rownoczenie.

__Finalizacja__

Po komunikacje o ponownym uruchomieniu w sieci docelowej:

```bash
poweroff
```

# ISO

1. Sklonuj SD na karty dla pozostalych pulpitow.
2. Skonfiguruj ostatecznie siec.
3. Wlacz pulpity. Uruchomia sie ponownie kilka razy, konczac konfiguracje. Uwazaj na komunikat o
4. Oczekuj komunikatu "Mentor wita!" na kazdym z pulpitow. Jezeli tak nie jest - cos poszlo nie tak.
			Pulpit pozornie zakonczy prace na minute przed ostatnim z ponownych uruchomien. Nie przeszkadzaj mu wtedy!

# install4lab (3)

1. Szukaj pulpitow: TAK, Konfiguruj backdoor SSH: NIE.
2. aaa.bbb.ccc.xxx-yyy - aaa.bbb.ccc prefix IP pulpitow + zakres koncowek (wyswietlone na RPI, xxx-xxx dla jednego
			pulpitu, __bezpiecznie 2-254__).
3. Ilosc pulpitow: zostanie nadpisane przez Test.
4. Test.
5. Ok? Dalej.
6. Force reinstall: NIE, Buduj zdalnie: NIE. Zmiana konfiguracji: TAK, NIE. Aktualizacja aplikacji: NIE, TAK.
