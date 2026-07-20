*&---------------------------------------------------------------------*
*& Include /MBSO/INVOICE_EDI_REP_TOP
*&---------------------------------------------------------------------*
*& Globale Definitionen: Datentypen und Klassen-Definition.
*&---------------------------------------------------------------------*

" Referenzstruktur fuer das Selektionsbild.
" Ersetzt das obsolete TABLES-Statement und liefert den SELECT-OPTIONS
" die DDIC-Typen (inkl. Suchhilfen) der jeweiligen Felder.
DATA:
  BEGIN OF selection_reference,
    billing_document TYPE vbrk-vbeln,
    sales_org        TYPE vbrk-vkorg,
    created_on       TYPE vbrk-erdat,
    sold_to          TYPE vbrk-kunag,
    payer            TYPE vbrk-kunrg,
  END OF selection_reference.

*&---------------------------------------------------------------------*
*& Lokale Klasse mit der gesamten Verarbeitungslogik.
*&---------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF output_row,
        billing_document TYPE vbrk-vbeln,
        created_on       TYPE vbrk-erdat,   " Erstelldatum der Rechnung
        sold_to          TYPE vbrk-kunag,   " Auftraggeber
        sold_to_name     TYPE kna1-name1,
        bill_to          TYPE vbpa-kunnr,   " Rechnungsempfaenger
        bill_to_name     TYPE kna1-name1,
        payer            TYPE vbrk-kunrg,   " Regulierer
        payer_name       TYPE kna1-name1,
        net_value        TYPE vbrk-netwr,   " Nettowert der Rechnung
        currency         TYPE vbrk-waerk,   " Belegwaehrung
      END OF output_row,
      output_table TYPE STANDARD TABLE OF output_row WITH EMPTY KEY.

    "! Ablaufsteuerung: selektiert die Daten und stellt sie dar.
    METHODS run.

    "! Liest die Rechnungen ohne Nachricht der gewaehlten Nachrichtenart
    "! samt Partnern und deren Namen.
    "! @parameter result | Aufbereitete Ergebniszeilen fuer die Ausgabe.
    METHODS select_data
      RETURNING VALUE(result) TYPE output_table.

    "! Gibt die Ergebnisliste als SALV-Tabelle aus.
    "! @parameter invoices | Anzuzeigende Ergebniszeilen.
    METHODS display
      IMPORTING invoices TYPE output_table.

  PRIVATE SECTION.
    CONSTANTS:
      billing_application TYPE nast-kappl VALUE 'V3',      " Fakturen
      partner_bill_to     TYPE parvw      VALUE 'RE',      " Rechn.-Empf.
      header_partner      TYPE vbpa-posnr VALUE '000000'.

    "! Setzt Kurz-, Mittel- und Langtext einer SALV-Spalte.
    METHODS set_column_text
      IMPORTING columns TYPE REF TO cl_salv_columns_table
                name    TYPE lvc_fname
                text    TYPE string.

ENDCLASS.
