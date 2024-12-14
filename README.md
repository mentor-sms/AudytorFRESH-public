# AudytorFRESH-public
To use with AudytorFRESH/installer4lab


# Podczas przygotowywania obrazu bazowego:

0) Potrzebny bedzie pendrive sformatowany FAT32
1) Jako sciezke wyjscia dla skryptu *prepare4lab.sh*, wybierz __katalog glowny__ pendrive i nie zmieniaj nazwy pliku
2) Bezpiecznie wysun urzadzenie :)
4) Podlacz klawiature do pulpitu, uruchom terminal i wykonaj polecenia (ignorujac znak nowej linii `$`):
```bash
$ cd /home/pi
$ curl -O https://raw.githubusercontent.com/mentor-sms/AudytorFRESH-public/release/copy4prepare.sh
$ chmod +x copy4prepare.sh
$ sleep 20 && /home/pi/copy4prepare.sh

6) Po 20 sekundach z pendrive zostanie pobrany i uruchomiany skrypt instalacyjny.
   Kiedy pierwszy raz skrypt zapyta o cos uzytkownika, mozna bezpiecznie wyjac pendrive i podlaczyc klawiature.
