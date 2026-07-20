*&---------------------------------------------------------------------*
*& Include /MBSO/INVOICE_EDI_REP_CL1
*&---------------------------------------------------------------------*
*& Klassen-Implementierung: gesamte Verarbeitungslogik.
*&---------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    display( select_data( ) ).
  ENDMETHOD.

  METHOD select_data.

    " 1) Rechnungskoepfe ohne Nachricht der gewaehlten Nachrichtenart.
    "    Auftraggeber (KUNAG) und Regulierer (KUNRG) sind Kopffelder
    "    der Faktura und daher direkt aus VBRK verfuegbar.
    SELECT vbeln, kunag, kunrg, netwr, waerk
      FROM vbrk
      WHERE vbeln IN @s_vbeln
        AND vkorg IN @s_vkorg
        AND erdat IN @s_erdat
        AND kunag IN @s_kunag
        AND kunrg IN @s_kunrg
        AND NOT EXISTS ( SELECT objky
                           FROM nast
                          WHERE kappl = @billing_application
                            AND objky = vbrk~vbeln
                            AND kschl = @p_kschl )
      INTO TABLE @DATA(invoices).

    IF invoices IS INITIAL.
      MESSAGE 'Keine Rechnungen zur Selektion gefunden' TYPE 'S'.
      RETURN.
    ENDIF.

    " 2) Rechnungsempfaenger (RE) aus den Kopfpartnern (VBPA) lesen.
    SELECT vbeln, kunnr
      FROM vbpa
      FOR ALL ENTRIES IN @invoices
      WHERE vbeln = @invoices-vbeln
        AND posnr = @header_partner
        AND parvw = @partner_bill_to
      INTO TABLE @DATA(bill_to_partners).
    SORT bill_to_partners BY vbeln.

    " 3) Ergebniszeilen aufbauen.
    result = VALUE #(
      FOR invoice IN invoices
      ( billing_document = invoice-vbeln
        sold_to          = invoice-kunag
        payer            = invoice-kunrg
        net_value        = invoice-netwr
        currency         = invoice-waerk
        bill_to          = VALUE #( bill_to_partners[ vbeln = invoice-vbeln ]-kunnr OPTIONAL ) ) ).

    " 4) Namen der Partner (Auftraggeber, Rechnungsempfaenger, Regulierer)
    "    in einem Zugriff nachlesen.
    DATA customers TYPE SORTED TABLE OF kna1-kunnr WITH UNIQUE KEY table_line.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<row>).
      INSERT <row>-sold_to INTO TABLE customers.
      INSERT <row>-bill_to INTO TABLE customers.
      INSERT <row>-payer   INTO TABLE customers.
    ENDLOOP.
    DELETE customers WHERE table_line IS INITIAL.

    IF customers IS INITIAL.
      RETURN.
    ENDIF.

    SELECT kunnr, name1
      FROM kna1
      FOR ALL ENTRIES IN @customers
      WHERE kunnr = @customers-table_line
      INTO TABLE @DATA(customer_names).
    SORT customer_names BY kunnr.

    LOOP AT result ASSIGNING <row>.
      <row>-sold_to_name = VALUE #( customer_names[ kunnr = <row>-sold_to ]-name1 OPTIONAL ).
      <row>-bill_to_name = VALUE #( customer_names[ kunnr = <row>-bill_to ]-name1 OPTIONAL ).
      <row>-payer_name   = VALUE #( customer_names[ kunnr = <row>-payer ]-name1 OPTIONAL ).
    ENDLOOP.

  ENDMETHOD.

  METHOD display.

    IF invoices IS INITIAL.
      RETURN.
    ENDIF.

    " SALV haelt eine Referenz auf die Tabelle -> aenderbare lokale Kopie.
    DATA(rows) = invoices.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = DATA(alv)
          CHANGING  t_table      = rows ).

        alv->get_functions( )->set_all( abap_true ).

        DATA(columns) = alv->get_columns( ).
        columns->set_optimize( abap_true ).

        " Waehrungsbezug fuer den Nettowert setzen.
        CAST cl_salv_column_list(
          columns->get_column( 'NET_VALUE' ) )->set_currency_column( 'CURRENCY' ).

        set_column_text( columns = columns name = 'BILLING_DOCUMENT' text = |Rechnung| ).
        set_column_text( columns = columns name = 'SOLD_TO'          text = |Auftraggeber| ).
        set_column_text( columns = columns name = 'SOLD_TO_NAME'     text = |Name Auftraggeber| ).
        set_column_text( columns = columns name = 'BILL_TO'          text = |Rechn.-Empf.| ).
        set_column_text( columns = columns name = 'BILL_TO_NAME'     text = |Name Rechn.-Empf.| ).
        set_column_text( columns = columns name = 'PAYER'            text = |Regulierer| ).
        set_column_text( columns = columns name = 'PAYER_NAME'       text = |Name Regulierer| ).
        set_column_text( columns = columns name = 'NET_VALUE'        text = |Nettowert| ).
        set_column_text( columns = columns name = 'CURRENCY'         text = |Waehrung| ).

        alv->display( ).

      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(error).
        MESSAGE error->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.

  METHOD set_column_text.
    TRY.
        DATA(column) = columns->get_column( name ).
        column->set_short_text( CONV scrtext_s( text ) ).
        column->set_medium_text( CONV scrtext_m( text ) ).
        column->set_long_text( CONV scrtext_l( text ) ).
      CATCH cx_salv_not_found.
        " Spalte nicht vorhanden -> Ueberschrift wird ignoriert.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
