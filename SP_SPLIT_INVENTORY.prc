CREATE OR REPLACE PROCEDURE SP_SPLIT_INVENTORY(P_INV_ID    NUMBER,
                                               P_INV_NAME  VARCHAR2,
                                               P_SPLIT_PER NUMBER,
                                               P_SUP_NAME  VARCHAR2,
                                               P_FRACTION  VARCHAR2,
                                               P_ID_PROOF  VARCHAR2) AS
  V_ID            INVENTORY_DTLS%ROWTYPE;
  LN_SPLIT_AMOUNT INVENTORY_DTLS.ASSET_AMNT%TYPE;
BEGIN
  BEGIN
    SELECT *
      INTO V_ID
      FROM INVENTORY_DTLS ID
     WHERE ID.INV_ID = P_INV_ID
       AND ID.STATUS = 'A';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20300,
                              'GIVEN INVENTORY IS NOT EXITS IN THE SYSTEM');
  END;
  IF V_ID.FRACTION = 'N' THEN
    RAISE_APPLICATION_ERROR(-20300,
                            'THIS INVENTORY SELECTED FRACTION IS NO, SO THIS INVENTORY YOU CAN NOT SPLIT');
  END IF;
  LN_SPLIT_AMOUNT := V_ID.ASSET_AMNT * P_SPLIT_PER / 100;

  IF LN_SPLIT_AMOUNT > NVL(V_ID.AVBL_AMNT, V_ID.ASSET_AMNT) THEN
    RAISE_APPLICATION_ERROR(-20300,
                            'THIS INVENTORY DOES NOT HAVE FUNDS TO SPLIT');
  END IF;
  --LN_SUP_ID:=SF_GET_SUP_ID(P_SUP_NAME)
  --NVL2 - IF EXP1 IS NULL THEN RETURNS EXP3, IF EXP1 IS NOT NULL THEN RETURNS EXP2
  SELECT NVL2(P_SUP_NAME, SF_GET_SUP_ID(P_SUP_NAME), V_ID.SUP_ID)
    INTO V_ID.SUP_ID
    FROM DUAL;
  INSERT INTO INVENTORY_DTLS
    (INV_ID,
     INV_NAME,
     ASSET_AMNT,
     OFFER_DATE,
     SUP_ID,
     COMD_ID,
     FRACTION,
     AVBL_AMNT,
     LOCK_AMNT,
     STATUS,
     ID_PROOF)
  VALUES
    (SEQ_INV_ID.NEXTVAL,
     P_INV_NAME,
     LN_SPLIT_AMOUNT,
     SYSDATE,
     V_ID.SUP_ID,
     V_ID.COMD_ID,
     NVL(P_FRACTION, V_ID.FRACTION),
     NULL,
     NULL,
     'A',
     P_ID_PROOF);

  UPDATE INVENTORY_DTLS ID
     SET ID.ASSET_AMNT = ID.ASSET_AMNT - LN_SPLIT_AMOUNT,
         ID.AVBL_AMNT = CASE
                          WHEN ID.AVBL_AMNT IS NOT NULL THEN
                           ID.AVBL_AMNT - LN_SPLIT_AMOUNT
                          ELSE
                           ID.AVBL_AMNT
                        END
   WHERE ID.INV_ID = P_INV_ID;
END;
/
