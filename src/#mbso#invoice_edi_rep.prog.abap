*&---------------------------------------------------------------------*
*& Report /MBSO/INVOICE_EDI_REP
*&---------------------------------------------------------------------*
*& Zeigt alle SD-Rechnungen (VBRK) an, zu denen KEINE Nachricht der in
*& der Selektion angegebenen Nachrichtenart (NAST-KSCHL, Applikation V3)
*& existiert.
*&
*& Selektion : Rechnungsnummer, Verkaufsorganisation, Erstelldatum,
*&             Auftraggeber, Regulierer (jeweils Range) sowie die
*&             Nachrichtenart (Einzelwert, Pflicht).
*& Ausgabe   : Rechnungsnr., Auftraggeber, Rechnungsempfaenger und
*&             Regulierer (jeweils mit Name) sowie Nettowert (SALV).
*&
*& Aufbau    : Standard-Include-Struktur des /MBSO/-Namensraums:
*&               _top  globale Definitionen (Typen, Klassen-Definition)
*&               _sel  Selektionsbild
*&               _cl1  Klassen-Implementierung (gesamte Logik)
*&---------------------------------------------------------------------*
REPORT /mbso/invoice_edi_rep.

INCLUDE /mbso/invoice_edi_rep_top.   " Globale Definitionen
INCLUDE /mbso/invoice_edi_rep_sel.   " Selektionsbild
INCLUDE /mbso/invoice_edi_rep_cl1.   " Klassen-Implementierung

START-OF-SELECTION.
  NEW lcl_report( )->run( ).
