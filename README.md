dkb-visa-read
=============
Kreditkarten-Buchungen der DKB mit Ruby/Mechanize abrufen

DKB-VISA-READ ist ein Ruby-Script, welches mit Hilfe der Mechanize-Bibliothek 
die Kreditkarten-Umsatze aus dem Online-Banking der DKB liest.

Die Umsätze werden als QIF-Dateien (Quicken Interchange Format) gespeichert 
und können dann z.B. von einer Homebanking-Software importiert werden.

Aufruf
------

    ./dkb-visa-read.rb [optionen] <Kontonummer>
        -t, --tage <TAGE>                Nur Umsaetze der letzten <TAGE> Tage lesen.
        -s, --start <DATUM>              Start-Datum ab dem die Umsaetze gelesen werden sollen (TT.MM.JJJJ).
        -l, --log                        Logdatei dkb-visa-read.log schreiben und HTML-Seiten sichern
        -z, --zugangsdaten <DATEI>       Kontonummer und Passwort aus Datei lesen
        -h, --help                       Diese Hilfe.

Weitere Informationen
---------------------
[Das Mini-Skript aus dem Artikel der c't 4/2010, Seite 129]
(http://www.heise.de/ct/projekte/machmit/webautomatisieren/wiki/DKB-VISA-READ)

Lizenz
------ 
Diese Software fällt unter den Lizenzvertrag CC-GNU GPL der Version 2.0 oder höher.
