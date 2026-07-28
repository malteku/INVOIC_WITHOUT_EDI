*&---------------------------------------------------------------------*
*& Include /MBSO/INVOICE_EDI_REP_SEL
*&---------------------------------------------------------------------*
*& Selektionsbild. Die Feldreferenzen stammen aus SELECTION_REFERENCE
*& (siehe _TOP-Include), damit kein obsoletes TABLES noetig ist.
*&---------------------------------------------------------------------*

SELECT-OPTIONS:
  s_vbeln FOR selection_reference-billing_document,   " Rechnungsnummer
  s_fkart FOR selection_reference-billing_type,       " Fakturaart
  s_vkorg FOR selection_reference-sales_org,          " Verkaufsorg.
  s_erdat FOR selection_reference-created_on,         " Erstelldatum
  s_kunag FOR selection_reference-sold_to,            " Auftraggeber
  s_kunre FOR selection_reference-bill_to,            " Rechn.-Empf.
  s_kunrg FOR selection_reference-payer.              " Regulierer

PARAMETERS:
  p_kschl  TYPE nast-kschl OBLIGATORY,                " Nachrichtenart
  p_nostor AS CHECKBOX.                               " Stornos ignorieren
