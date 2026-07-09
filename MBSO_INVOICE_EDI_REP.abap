*&---------------------------------------------------------------------*
*& Report /MBSO/INVOICE_EDI_REP
*&---------------------------------------------------------------------*
*& Zeigt alle SD-Rechnungen (VBRK) an, zu denen KEINE Nachricht der in
*& der Selektion angegebenen Nachrichtenart (NAST-KSCHL, Applikation V3)
*& existiert.
*&
*& Selektion : Rechnungsnummer (Range), Verkaufsorganisation (Range),
*&             Erstelldatum (Range), Auftraggeber (Range),
*&             Regulierer (Range), Nachrichtenart (Einzelwert, Pflicht).
*& Ausgabe   : Rechnungsnr., Auftraggeber, Rechnungsempfaenger,
*&             Regulierer (jeweils mit Name) sowie Nettowert (SALV).
*&
*& Hinweis   : Auf-/Regulierer werden aus den VBRK-Kopffeldern KUNAG/
*&             KUNRG selektiert; der Rechnungsempfaenger (RE) stammt aus
*&             den Kopfpartnern (VBPA, POSNR = '000000'). Die Pruefung
*&             auf vorhandene Nachrichten erfolgt gegen NAST mit der
*&             Applikation 'V3' (SD-Fakturen).
*&---------------------------------------------------------------------*
REPORT /mbso/invoice_edi_rep.

*----------------------------------------------------------------------*
* Selektionsbild
*----------------------------------------------------------------------*
TABLES vbrk.

SELECT-OPTIONS:
  s_vbeln FOR vbrk-vbeln,                        " Rechnungsnummer (SD)
  s_vkorg FOR vbrk-vkorg,                        " Verkaufsorganisation
  s_erdat FOR vbrk-erdat,                        " Erstelldatum Rechnung
  s_kunag FOR vbrk-kunag,                        " Auftraggeber
  s_kunrg FOR vbrk-kunrg.                        " Regulierer

PARAMETERS:
  p_kschl TYPE nast-kschl OBLIGATORY.            " Nachrichtenart

*----------------------------------------------------------------------*
* Lokale Klasse mit der gesamten Verarbeitungslogik
*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_out,
        vbeln   TYPE vbrk-vbeln,
        kunag   TYPE vbrk-kunag,     " Auftraggeber
        name_ag TYPE kna1-name1,
        kunre   TYPE vbpa-kunnr,     " Rechnungsempfaenger
        name_re TYPE kna1-name1,
        kunrg   TYPE vbrk-kunrg,     " Regulierer
        name_rg TYPE kna1-name1,
        netwr   TYPE vbrk-netwr,     " Nettowert der Rechnung
        waerk   TYPE vbrk-waerk,     " Belegwaehrung
      END OF ty_out,
      ty_out_tab TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    METHODS:
      "! Ablaufsteuerung: selektiert die Daten und stellt sie dar.
      run,
      "! Liest die Rechnungen ohne Nachricht der Nachrichtenart inkl.
      "! Partner und Namen.
      "! @parameter rt_out | Aufbereitete Ergebniszeilen fuer die Ausgabe.
      select_data
        RETURNING VALUE(rt_out) TYPE ty_out_tab,
      "! Gibt die Ergebnisliste als SALV-Tabelle aus.
      "! @parameter it_out | Anzuzeigende Ergebniszeilen.
      display
        IMPORTING it_out TYPE ty_out_tab.

  PRIVATE SECTION.
    METHODS set_col_text
      IMPORTING io_cols TYPE REF TO cl_salv_columns_table
                col     TYPE lvc_fname
                text    TYPE string.

    CONSTANTS:
      c_kappl_billing TYPE nast-kappl VALUE 'V3',   " Applikation Fakturen
      c_parvw_ag      TYPE parvw      VALUE 'AG',
      c_parvw_re      TYPE parvw      VALUE 'RE',
      c_parvw_rg      TYPE parvw      VALUE 'RG',
      c_posnr_header  TYPE vbpa-posnr VALUE '000000'.

ENDCLASS.

CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    display( select_data( ) ).
  ENDMETHOD.

  METHOD select_data.

    " 1) Rechnungskoepfe ohne Nachricht der gewuenschten Nachrichtenart
    SELECT vbeln, kunag, kunrg, netwr, waerk
      FROM vbrk
      WHERE vbeln IN @s_vbeln
        AND vkorg IN @s_vkorg
        AND erdat IN @s_erdat
        AND kunag IN @s_kunag
        AND kunrg IN @s_kunrg
        AND NOT EXISTS ( SELECT objky
                           FROM nast
                          WHERE nast~kappl = @c_kappl_billing
                            AND nast~objky = vbrk~vbeln
                            AND nast~kschl = @p_kschl )
      INTO TABLE @DATA(lt_vbrk).

    IF lt_vbrk IS INITIAL.
      MESSAGE 'Keine Rechnungen zur Selektion gefunden' TYPE 'S'.
      RETURN.
    ENDIF.

    " 2) Partner (Auftraggeber, Rechnungsempfaenger, Regulierer)
    "    aus den Kopfpartnern der Faktura lesen
    SELECT vbeln, parvw, kunnr
      FROM vbpa
      FOR ALL ENTRIES IN @lt_vbrk
      WHERE vbeln = @lt_vbrk-vbeln
        AND posnr = @c_posnr_header
        AND parvw IN ( @c_parvw_ag, @c_parvw_re, @c_parvw_rg )
      INTO TABLE @DATA(lt_vbpa).
    SORT lt_vbpa BY vbeln parvw.

    " 3) Ergebnistabelle aufbauen, Partnernummern setzen
    rt_out = VALUE #( FOR wa IN lt_vbrk
                      ( vbeln = wa-vbeln
                        kunag = wa-kunag       " Kopfpartner Auftraggeber
                        kunrg = wa-kunrg       " Kopfpartner Regulierer
                        netwr = wa-netwr
                        waerk = wa-waerk ) ).

    LOOP AT rt_out ASSIGNING FIELD-SYMBOL(<out>).
      " Rechnungsempfaenger stammt nur aus VBPA
      <out>-kunre = VALUE #( lt_vbpa[ vbeln = <out>-vbeln
                                      parvw = c_parvw_re ]-kunnr OPTIONAL ).
      " Falls Auftraggeber/Regulierer im Kopf nicht gefuellt: aus VBPA
      IF <out>-kunag IS INITIAL.
        <out>-kunag = VALUE #( lt_vbpa[ vbeln = <out>-vbeln
                                        parvw = c_parvw_ag ]-kunnr OPTIONAL ).
      ENDIF.
      IF <out>-kunrg IS INITIAL.
        <out>-kunrg = VALUE #( lt_vbpa[ vbeln = <out>-vbeln
                                        parvw = c_parvw_rg ]-kunnr OPTIONAL ).
      ENDIF.
    ENDLOOP.

    " 4) Namen der Partner nachlesen
    DATA lt_kunnr TYPE SORTED TABLE OF kna1-kunnr WITH UNIQUE KEY table_line.
    LOOP AT rt_out ASSIGNING <out>.
      INSERT <out>-kunag INTO TABLE lt_kunnr.
      INSERT <out>-kunre INTO TABLE lt_kunnr.
      INSERT <out>-kunrg INTO TABLE lt_kunnr.
    ENDLOOP.
    DELETE lt_kunnr WHERE table_line IS INITIAL.

    IF lt_kunnr IS NOT INITIAL.
      SELECT kunnr, name1
        FROM kna1
        FOR ALL ENTRIES IN @lt_kunnr
        WHERE kunnr = @lt_kunnr-table_line
        INTO TABLE @DATA(lt_kna1).
      SORT lt_kna1 BY kunnr.

      LOOP AT rt_out ASSIGNING <out>.
        <out>-name_ag = VALUE #( lt_kna1[ kunnr = <out>-kunag ]-name1 OPTIONAL ).
        <out>-name_re = VALUE #( lt_kna1[ kunnr = <out>-kunre ]-name1 OPTIONAL ).
        <out>-name_rg = VALUE #( lt_kna1[ kunnr = <out>-kunrg ]-name1 OPTIONAL ).
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD display.

    IF it_out IS INITIAL.
      RETURN.
    ENDIF.

    DATA lo_alv TYPE REF TO cl_salv_table.

    " SALV haelt eine Referenz auf die Tabelle -> aenderbare lokale Kopie
    DATA(lt_display) = it_out.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = lt_display ).

        DATA(lo_functions) = lo_alv->get_functions( ).
        lo_functions->set_all( abap_true ).

        lo_alv->get_columns( )->set_optimize( abap_true ).

        " Waehrungsbezug fuer den Nettowert setzen
        DATA(lo_cols) = lo_alv->get_columns( ).
        CAST cl_salv_column_list(
          lo_cols->get_column( 'NETWR' ) )->set_currency_column( 'WAERK' ).

        " Spaltenueberschriften
        set_col_text( io_cols = lo_cols col = 'VBELN'   text = 'Rechnung' ).
        set_col_text( io_cols = lo_cols col = 'KUNAG'   text = 'Auftraggeber' ).
        set_col_text( io_cols = lo_cols col = 'NAME_AG' text = 'Name Auftraggeber' ).
        set_col_text( io_cols = lo_cols col = 'KUNRE'   text = 'Rechn.-Empf.' ).
        set_col_text( io_cols = lo_cols col = 'NAME_RE' text = 'Name Rechn.-Empf.' ).
        set_col_text( io_cols = lo_cols col = 'KUNRG'   text = 'Regulierer' ).
        set_col_text( io_cols = lo_cols col = 'NAME_RG' text = 'Name Regulierer' ).
        set_col_text( io_cols = lo_cols col = 'NETWR'   text = 'Nettowert' ).
        set_col_text( io_cols = lo_cols col = 'WAERK'   text = 'Waehrung' ).

        lo_alv->display( ).

      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.

  METHOD set_col_text.
    TRY.
        DATA(lo_col) = io_cols->get_column( col ).
        lo_col->set_short_text( CONV scrtext_s( text ) ).
        lo_col->set_medium_text( CONV scrtext_m( text ) ).
        lo_col->set_long_text( CONV scrtext_l( text ) ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
START-OF-SELECTION.
  NEW lcl_report( )->run( ).
