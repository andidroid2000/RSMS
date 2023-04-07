-- <<Exercitiul 14>>
--      In luna ianuarie a fiecarui an, magazinele isi actualizeaza cifra lunara de vanzari, iar producatorii si posturile TV tarifele.
--      Sa se actualizeze baza de date in functie de noile valori si sa se afiseze schimbarile.
SET serveroutput ON;

CREATE OR REPLACE PACKAGE pachet_14 AS
    TYPE rec_cmp IS RECORD
        ( 
          cod lant_companii.cod_companie%TYPE,
          nume lant_companii.nume_companie%TYPE,
          ca_v lant_companii.cifra_afaceri%TYPE,
          ca_n lant_companii.cifra_afaceri%TYPE
        );
     TYPE rec_mkt IS RECORD
        ( --cod_companie campanii_marketing.cod_companie%TYPE,
          cod_marketing campanii_marketing.cod_marketing%TYPE,
          nume campanii_marketing.nume_campanie%TYPE,
          suma NUMBER(12,2)
        );
    TYPE tab_situatie_mkt IS TABLE OF rec_mkt;
    t_situatie_mkt tab_situatie_mkt;
    
    TYPE tab_situatie_companii IS TABLE OF rec_cmp INDEX BY PLS_INTEGER;
    t_situatie_companii tab_situatie_companii;
    
    FUNCTION actualizare_cifra_afaceri(v_cod_companie IN lant_companii.cifra_afaceri%TYPE) RETURN spatii_comerciale.cifra_vanzari%TYPE;
    FUNCTION actualizare_off_on(v_cod_campanie IN campanii_marketing.cod_marketing%TYPE) RETURN campanii_marketing.buget%TYPE;
    PROCEDURE actualizare_companii;
    PROCEDURE actualizare;
    PROCEDURE actualizare_cmp_mkt;
    
END pachet_14;

CREATE OR REPLACE PACKAGE BODY pachet_14 AS

--  se calculeaza cifra de afaceri a fiecarei companii insuman cifra de vanzari a fiecarui magazin pe care il detin
    FUNCTION actualizare_cifra_afaceri(v_cod_companie IN lant_companii.cifra_afaceri%TYPE)
    RETURN spatii_comerciale.cifra_vanzari%TYPE IS v_ca_noua spatii_comerciale.cifra_vanzari%TYPE;
    BEGIN
        SELECT SUM(cifra_vanzari) INTO v_ca_noua
        FROM spatii_comerciale sc, lant_companii lc
        WHERE sc.cod_companie = lc.cod_companie
            AND sc.cod_companie = v_cod_companie
        GROUP BY sc.cod_companie;
        RETURN v_ca_noua;
    END actualizare_cifra_afaceri;
  
--  se calculeaza bugetul necesar pentru desfasurarea campaniilor de marketing in mediul online si offline    
    FUNCTION actualizare_off_on(v_cod_campanie IN campanii_marketing.cod_marketing%TYPE)
    RETURN campanii_marketing.buget%TYPE IS v_bug spatii_comerciale.cifra_vanzari%TYPE := 0;
    v_off camp_offline.buget_offline%TYPE;
    v_on camp_online.buget_online%TYPE;
    BEGIN
    --  daca nu se desfasoara campania offline, atunci se intoarce 0
        BEGIN
            SELECT buget_offline INTO v_off FROM camp_offline WHERE cod_marketing = v_cod_campanie;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_off := 0;
        END;
    --  daca nu se desfasoara campania online, atunci se intoarce 0
        BEGIN
            SELECT buget_online INTO v_on FROM camp_online WHERE cod_marketing = v_cod_campanie;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_on := 0;
        END;
        v_bug := v_on + v_off;
        RETURN v_bug;
    END actualizare_off_on;
    
    PROCEDURE actualizare_companii IS
    CURSOR c IS
        SELECT cod_companie, nume_companie
        FROM lant_companii
        ORDER BY cod_companie;
    v_ca_veche lant_companii.cifra_afaceri%TYPE;
    v_ca_noua lant_companii.cifra_afaceri%TYPE;
    BEGIN
        FOR companie IN c LOOP
            SELECT cifra_afaceri INTO v_ca_veche FROM lant_companii WHERE cod_companie = companie.cod_companie;
            v_ca_noua := actualizare_cifra_afaceri(companie.cod_companie);
            t_situatie_companii(companie.cod_companie).cod := companie.cod_companie;
            t_situatie_companii(companie.cod_companie).nume := companie.nume_companie;
            t_situatie_companii(companie.cod_companie).ca_v := v_ca_veche;
            t_situatie_companii(companie.cod_companie).ca_n := v_ca_noua;
            -- UPDATE lant_companii SET cifra_afaceri = v_ca_noua WHERE cod_companie = companie.cod_companie;
        END LOOP;
    END actualizare_companii;
     
    PROCEDURE actualizare_cmp_mkt IS
    BEGIN
        SELECT cm.cod_marketing, cm.nume_campanie, ROUND(SUM(t.difuzare_int1*60/t.durata_spot*pt.cost_int1 + t.difuzare_int2*60/t.durata_spot*pt.cost_int2)) * MIN(cm.finalizare - SYSDATE) suma 
        BULK COLLECT INTO t_situatie_mkt
        FROM televizat t, post_tv pt, campanii_marketing cm
        WHERE t.cod_tv = pt.cod_tv
            AND t.cod_marketing = cm.cod_marketing
            AND cm.finalizare - SYSDATE >0
    GROUP BY cm.cod_marketing, cm.nume_campanie;
    END actualizare_cmp_mkt;
    
    
    PROCEDURE actualizare IS
    v_aux lant_companii.cifra_afaceri%TYPE;
    v_bug NUMBER(14,2);
    BEGIN
        actualizare_companii;
        actualizare_cmp_mkt;
        DBMS_OUTPUT.PUT_LINE('<O> Situatia cifrei de afaceri ale companiilor:');
        FOR i IN t_situatie_companii.FIRST..t_situatie_companii.LAST LOOP
            v_aux := (TRUNC(t_situatie_companii(i).ca_n/t_situatie_companii(i).ca_v-1, 2))*100;
            IF t_situatie_companii(i).ca_n - t_situatie_companii(i).ca_v > 0 THEN
                DBMS_OUTPUT.PUT_LINE('   # Compania ' || upper(t_situatie_companii(i).nume) || ' a avut o crestere a cifrei de afaceri de la:');
                DBMS_OUTPUT.PUT_LINE('      '||  t_situatie_companii(i).ca_v || ' RON la '|| t_situatie_companii(i).ca_n || ' RON (+'|| v_aux || '%)');
            ELSE
                DBMS_OUTPUT.PUT_LINE('   # Compania ' || upper(t_situatie_companii(i).nume) || ' a avut o scadere a cifrei de afaceri de la:');
                DBMS_OUTPUT.PUT_LINE('      '||  t_situatie_companii(i).ca_v || ' RON la '|| t_situatie_companii(i).ca_n || ' RON ('|| v_aux || '%)');
            END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('<O> Situatia campaniilor ce au contracte de televiziune in desfasurare desfasurare:');
        FOR i IN 1..t_situatie_mkt.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE(i || '. Bugetul televizat al campaniei '|| t_situatie_mkt(i).nume || ' se situeaza la suma de ' || t_situatie_mkt(i).suma || ' RON  pentru anul curent.');
                DBMS_OUTPUT.PUT_LINE('   La acesta se adauga bugetul pentru campaniile online si offline de ' || actualizare_off_on(t_situatie_mkt(i).cod_marketing) || ' RON');
                v_bug :=  t_situatie_mkt(i).suma + actualizare_off_on(t_situatie_mkt(i).cod_marketing);
                DBMS_OUTPUT.PUT_LINE('   TOTAL BUGET ANUL CURENT: ' || v_bug || ' RON');
        END LOOP;
    END actualizare;
END pachet_14;

EXECUTE pachet_14.actualizare;

