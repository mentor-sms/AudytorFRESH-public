# AudytorFRESH-public

To use with AudytorFRESH/installer4lab

# Przygotowanie pulpitu:

Świeży, zaktualizowany system Debian Raspberry (ignorujac znak nowej linii `$`):
```bash
$ sudo apt update
$ sudo apt full-upgrade
$ sudo apt autoremove
$ sudo apt clean
```

Dodatkowo:
```bash
$ sudo apt install dos2unix
```

# Podczas przygotowywania obrazu bazowego:

0) Potrzebny bedzie pendrive sformatowany FAT32
1) Jako sciezke wyjscia dla skryptu *prepare4lab.sh*, wybierz __katalog glowny__ pendrive i nie zmieniaj nazwy pliku
2) Bezpiecznie usun urzadzenie :)

4) Podlacz klawiature do pulpitu, uruchom terminal i wykonaj polecenia (ignorujac znak nowej linii `$`):
   (GitHubUserContent.com)
```bash
$ cd ~ && curl -L -o copy4prepare.sh https://tinyurl.com/copy4prepare


$ dos2unix -f -k ~/copy4prepare.sh
$ chmod +x ~/copy4prepare.sh
$ ~/copy4prepare.sh --help
$ sudo ~/copy4prepare.sh
```

5) Postępuj zgodnie z instrukcjami na ekranie pulitu.
6)
