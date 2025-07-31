CREATE OR REPLACE PROCEDURE SP_LOAN_ALGORITHM(P_LOAN_AMNT NUMBER,
                                              P_COMD_NAME VARCHAR2) AS
  LN_LOAN_AMNT INVENTORY_DTLS.ASSET_AMNT%TYPE := P_LOAN_AMNT;

  CURSOR CUR_INV_DATA IS
    SELECT ID.INV_ID,
           ID.ASSET_AMNT,
           ID.SUP_ID,
           ID.LOCK_AMNT,
           NVL(ID.AVBL_AMNT, ID.ASSET_AMNT) AVBL_AMNT,
           ID.FRACTION
      FROM INVENTORY_DTLS ID, MST_COMMODITY MC
     WHERE ID.COMD_ID = MC.COMD_ID
       AND MC.COMD_NAME = UPPER(P_COMD_NAME)
       AND ID.ASSET_AMNT <> NVL(ID.LOCK_AMNT, 0)
       AND ID.STATUS = 'A'
       AND MC.STATUS = 'A'
     ORDER BY ID.OFFER_DATE;
  LN_INV_PAR_PER  TRAN_INV_FRACTION.INV_PAR_PER%TYPE;
  LN_INV_TRAN_PER TRAN_INV_FRACTION.INV_TRA_PAR_PER%TYPE;
  LN_TRAN_ID      TRANSACTION_SUMMARY.TRAN_ID%TYPE;
  LN_SUP_PER      APP_CONFIG_DTLS.VALUE%TYPE;
  LN_OWNER_PER    APP_CONFIG_DTLS.VALUE%TYPE;
  LN_INV_PER      APP_CONFIG_DTLS.VALUE%TYPE;

  --WITH 'UPDATE' AND 'DELETE' WE SHOULD WRITE WHERE CLAUSE
BEGIN
  IF SF_GET_LOAN_STATUS(P_LOAN_AMNT, P_COMD_NAME) THEN
    LN_TRAN_ID := SEQ_TRAN_ID.NEXTVAL;
  
    SELECT ACD.VALUE
      INTO LN_SUP_PER
      FROM APP_CONFIG_DTLS ACD
     WHERE ACD.MAIN_MODULE = 'LOAN MODULE'
       AND ACD.SUB_MODULE = 'SUP_PERCENTAGE'
       AND ACD.STATUS = 'A';
    SELECT ACD.VALUE
      INTO LN_OWNER_PER
      FROM APP_CONFIG_DTLS ACD
     WHERE ACD.MAIN_MODULE = 'LOAN MODULE'
       AND ACD.SUB_MODULE = 'OWNER_PERCENTAGE'
       AND ACD.STATUS = 'A';
    SELECT ACD.VALUE
      INTO LN_INV_PER
      FROM APP_CONFIG_DTLS ACD
     WHERE ACD.MAIN_MODULE = 'LOAN MODULE'
       AND ACD.SUB_MODULE = 'INV_PERCENTAGE'
       AND ACD.STATUS = 'A';
  
    INSERT INTO TRANSACTION_SUMMARY
      (tran_id,
       tran_amount,
       tran_date,
       comd_id,
       sup_per,
       owner_per,
       inv_per,
       status)
    VALUES
      (LN_TRAN_ID,
       P_LOAN_AMNT,
       SYSDATE,
       SF_GET_COMD_ID(P_COMD_NAME),
       LN_SUP_PER,
       LN_OWNER_PER,
       LN_INV_PER,
       'A');
    FOR I IN CUR_INV_DATA LOOP
      IF LN_LOAN_AMNT > I.AVBL_AMNT THEN
        UPDATE INVENTORY_DTLS ID
           SET ID.AVBL_AMNT = 0, ID.LOCK_AMNT = ID.ASSET_AMNT
         WHERE ID.INV_ID = I.INV_ID;
        --TRAN_INV_FRACTION INSERT
        LN_INV_PAR_PER  := I.AVBL_AMNT / I.ASSET_AMNT * 100;
        LN_INV_TRAN_PER := I.AVBL_AMNT / P_LOAN_AMNT * 100;
        INSERT INTO TRAN_INV_FRACTION
          (inv_id,
           inv_par_amnt,
           tran_id,
           sup_id,
           inv_par_per,
           inv_tra_par_per,
           status)
        VALUES
          (I.INV_ID,
           I.AVBL_AMNT,
           LN_TRAN_ID,
           I.SUP_ID,
           LN_INV_PAR_PER,
           LN_INV_TRAN_PER,
           'A');
      
        LN_LOAN_AMNT := LN_LOAN_AMNT - I.AVBL_AMNT;
      
      ELSIF LN_LOAN_AMNT = I.AVBL_AMNT THEN
        UPDATE INVENTORY_DTLS ID
           SET ID.AVBL_AMNT = 0, ID.LOCK_AMNT = ID.ASSET_AMNT
         WHERE ID.INV_ID = I.INV_ID;
      
        --TRAN_INV_FRACTION INSERT
        LN_INV_PAR_PER  := I.AVBL_AMNT / I.ASSET_AMNT * 100;
        LN_INV_TRAN_PER := I.AVBL_AMNT / P_LOAN_AMNT * 100;
        INSERT INTO TRAN_INV_FRACTION
          (inv_id,
           inv_par_amnt,
           tran_id,
           sup_id,
           inv_par_per,
           inv_tra_par_per,
           status)
        VALUES
          (I.INV_ID,
           I.AVBL_AMNT,
           LN_TRAN_ID,
           I.SUP_ID,
           LN_INV_PAR_PER,
           LN_INV_TRAN_PER,
           'A');
      
        LN_LOAN_AMNT := 0;
        --EXIT; --ADDED BY ME
      ELSIF LN_LOAN_AMNT < I.AVBL_AMNT AND I.FRACTION = 'Y' THEN
        UPDATE INVENTORY_DTLS ID
           SET ID.AVBL_AMNT = NVL(ID.AVBL_AMNT, ID.ASSET_AMNT) -
                              LN_LOAN_AMNT,
               ID.LOCK_AMNT = NVL(ID.LOCK_AMNT, 0) + LN_LOAN_AMNT
         WHERE ID.INV_ID = I.INV_ID;
      
        --FRACTION INSERT
        LN_INV_PAR_PER  := LN_LOAN_AMNT / I.ASSET_AMNT * 100;
        LN_INV_TRAN_PER := LN_LOAN_AMNT / P_LOAN_AMNT * 100;
        INSERT INTO TRAN_INV_FRACTION
          (inv_id,
           inv_par_amnt,
           tran_id,
           sup_id,
           inv_par_per,
           inv_tra_par_per,
           status)
        VALUES
          (I.INV_ID,
           LN_LOAN_AMNT,
           LN_TRAN_ID,
           I.SUP_ID,
           LN_INV_PAR_PER,
           LN_INV_TRAN_PER,
           'A');
      
        LN_LOAN_AMNT := 0;
      
      END IF;
      IF LN_LOAN_AMNT = 0 THEN
        EXIT;
      END IF;
    END LOOP;
  ELSE
    RAISE_APPLICATION_ERROR(-20300,
                            'BANK DOES NOT HAVE FUNDS TO GIVE LOAN FOR THIS COMMODITY');
  
  END IF;
END;
/
