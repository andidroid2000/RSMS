SET serveroutput ON;

CREATE OR REPLACE PACKAGE pachet_13 AS
    PROCEDURE ex_6(v_tip_magazin IN lant_companii.tip_magazin%TYPE, v_nume_judet IN judete.nume_jud%TYPE);
    PROCEDURE ex_7(v_tip_magazin IN lant_companii.tip_magazin%TYPE);
    FUNCTION ex_8(v_nume_companie IN lant_companii.nume_companie%TYPE) RETURN NUMBER;
    FUNCTION cel_mai_bun(v_cod_companie IN spatii_comerciale.cod_companie%TYPE, v_cod_localitate IN spatii_comerciale.cod_localitate%TYPE) RETURN spatii_comerciale.cod_magazin%TYPE;
    PROCEDURE ex_9(v_nume_companie IN lant_companii.nume_companie%TYPE);
END pachet_13;
/
CREATE OR REPLACE PACKAGE BODY pachet_13 AS
    
-- <<Exercitiul 6>>

PROCEDURE ex_6 (v_tip_magazin IN lant_companii.tip_magazin%TYPE, v_nume_judet IN judete.nume_jud%TYPE)
IS
    TYPE rec_magazin IS RECORD
        ( s_mag spatii_comerciale.suprafata_mag%TYPE,
          ca spatii_comerciale.cifra_vanzari%TYPE,
          localitate spatii_comerciale.cod_localitate%TYPE,
          companie spatii_comerciale.cod_companie%TYPE,
          an spatii_comerciale.data_deschidere%TYPE,
          cod spatii_comerciale.cod_magazin%TYPE
        );
        
    TYPE tab_magazine IS TABLE OF rec_magazin INDEX BY BINARY_INTEGER;
    t_mag_profil tab_magazine;

    
    -- tabel imbricat
    TYPE tab_companii IS TABLE OF lant_companii.cod_companie%TYPE;
    t_comp_profil tab_companii;
    
    TYPE tab_localitati IS TABLE OF localitati.cod_localitate%TYPE;
    t_loc tab_localitati;
    
    v_cod_judet judete.cod_judet%TYPE;
    v_comp lant_companii.nume_companie%TYPE;
    v_loc localitati.nume_loc%TYPE;
    v_ca_totala lant_companii.cifra_afaceri%TYPE;
     
BEGIN
    BEGIN -- verificarea datelor introduse
        SELECT cod_judet
        INTO v_cod_judet
        FROM judete
        WHERE lower(nume_jud) = lower(v_nume_judet);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_cod_judet := NULL;
            DBMS_OUTPUT.PUT_LINE (upper(v_nume_judet)||' nu este un judet!');
    END;
    IF v_cod_judet IS NOT NULL THEN  
        SELECT cod_companie
        BULK COLLECT INTO t_comp_profil
        FROM lant_companii
        WHERE lower(tip_magazin) = lower(v_tip_magazin);
        
        
        
        IF t_comp_profil.COUNT = 0 THEN -- verificarea datelor introduse
            DBMS_OUTPUT.PUT_LINE ('Acest tip de magazin: '||upper(v_tip_magazin)||', nu este inregistrat in baza de date!');          
        ELSE  
            DBMS_OUTPUT.PUT_LINE ('<< Situatia magazinelor tip ' || upper(v_tip_magazin) || ' din judetul ' || upper(v_nume_judet) || '>>');      
            SELECT cod_localitate
            BULK COLLECT INTO t_loc
            FROM localitati
            WHERE v_cod_judet = cod_judet;
            
            SELECT suprafata_mag, cifra_vanzari, cod_localitate, cod_companie, data_deschidere, cod_magazin
            BULK COLLECT INTO t_mag_profil
            FROM spatii_comerciale
            ORDER BY cod_companie, cod_localitate, cifra_vanzari, suprafata_mag;
            
            FOR i IN t_mag_profil.FIRST..t_mag_profil.LAST LOOP
                IF t_mag_profil(i).companie MEMBER OF t_comp_profil AND t_mag_profil(i).localitate MEMBER OF t_loc THEN
                    
                    SELECT nume_companie, cifra_afaceri
                    INTO v_comp, v_ca_totala
                    FROM lant_companii
                    WHERE cod_companie = t_mag_profil(i).companie;
                    
                    SELECT nume_loc
                    INTO v_loc
                    FROM localitati
                    WHERE cod_localitate = t_mag_profil(i).localitate; 
                    
                    DBMS_OUTPUT.PUT_LINE('<O> ' || upper(v_comp) || ' ' || t_mag_profil(i).cod || ' ' || v_loc); 
                    DBMS_OUTPUT.PUT_LINE('  # Procent cira afaceri: ' || trunc(t_mag_profil(i).ca/ v_ca_totala, 3)|| '%'); 
                    DBMS_OUTPUT.PUT_LINE('  # An deschidere: ' || t_mag_profil(i).an); 
                    DBMS_OUTPUT.PUT_LINE('  # Suprafata: ' || t_mag_profil(i).s_mag || ' m.p.'); 
                END IF;
            END LOOP;
        
        END IF;
    END IF;
END ex_6;

-- <<Exercitiul 7>>

--      Sa se afiseze pentru magazinele de un anumit tip (discount, constructii, proximitate) situatia actuala
-- a aprovizionarii. Se va calcula pretul aprovizionarii fiecarui magazin, stiind ca marfa de la un centru logistic este impartita
-- in mod egal intre magazine.

PROCEDURE ex_7 (v_tip_magazin IN lant_companii.tip_magazin%TYPE) IS
    CURSOR magazine IS
        SELECT cod_magazin, lc.cod_companie, nume_companie, nume_loc, cod_logistic
        FROM spatii_comerciale sc, lant_companii lc, localitati l
        WHERE sc.cod_companie = lc.cod_companie
            AND sc.cod_localitate = l.cod_localitate
        ORDER BY nume_companie, l.nume_loc;
        
    CURSOR aprovizionare (centru_logistic contracte.cod_logistic%TYPE) IS
        SELECT nume_producator, nume_produs, tara, cantitate_prod, nume_distribuitor, p.pret_unitar, c.id_comanda
        FROM contracte c, distribuitor d, producatori p
        WHERE c.cod_producator = p.cod_producator
            AND c.cod_distribuitor = d.cod_distribuitor
            AND c.cod_logistic = centru_logistic;
            
    v_cod_magazin spatii_comerciale.cod_magazin%TYPE; 
    v_cod_companie spatii_comerciale.cod_companie%TYPE; 
    v_nume_companie lant_companii.nume_companie%TYPE; 
    v_nume_loc localitati.nume_loc%TYPE; 
    v_cod_logistic spatii_comerciale.cod_logistic%TYPE;
    v_aux INTEGER;
    TYPE tab_mag_tip IS TABLE OF lant_companii.cod_companie%TYPE;
    mag_tip tab_mag_tip;
     
    BEGIN
        -- se inregistreaza companiile care sunt de tipul introdus
        SELECT cod_companie BULK COLLECT INTO mag_tip
        FROM lant_companii
        WHERE LOWER(v_tip_magazin) = LOWER(tip_magazin);
        -- DBMS_OUTPUT.PUT_LINE(mag_tip.COUNT);
        OPEN magazine;
        LOOP
            FETCH magazine INTO v_cod_magazin, v_cod_companie, v_nume_companie, v_nume_loc, v_cod_logistic;
            EXIT WHEN magazine%NOTFOUND;
            -- DBMS_OUTPUT.PUT_LINE(v_cod_companie); 
            -- pentru magazinele care sunt de tipul introdus se afiseaza aprovizionarea
            IF v_cod_companie MEMBER OF mag_tip THEN
                DBMS_OUTPUT.PUT_LINE('<O> '||upper(v_nume_companie) || ' ' || v_cod_magazin ||' '|| v_nume_loc); 
                FOR a IN aprovizionare (v_cod_logistic) LOOP 
                    -- se calculeaza numarul de magazine care se aprovizioneaza de la acelasi
                    -- centru logistic
                    SELECT COUNT(v_cod_magazin) INTO v_aux FROM spatii_comerciale WHERE cod_logistic = v_cod_logistic;
                    DBMS_OUTPUT.PUT_LINE ('  ' || '<< Aprovizionare lunara comanda' || a.id_comanda||' >>');
                    DBMS_OUTPUT.PUT_LINE ('  # '||a.nume_produs||', ' || ROUND(a.cantitate_prod/v_aux) || ' unitati, pret total ' || ROUND(a.cantitate_prod/v_aux*a.pret_unitar) || ' RON');
                    DBMS_OUTPUT.PUT_LINE ('  # Detalii:');
                    DBMS_OUTPUT.PUT_LINE('      - Producator: ' || a.nume_producator || ', ' || a.tara); 
                    DBMS_OUTPUT.PUT_LINE('      - Distribuitor: ' || a.nume_distribuitor); 
                END LOOP;
            END IF;
        END LOOP;
        CLOSE magazine;
END ex_7;

-- <<Exercitiul 8>>

--      Sa se afiseze pentru o companie x pretul mediu platit per minut pentru publicitate televizata.

FUNCTION ex_8(v_nume_companie IN lant_companii.nume_companie%TYPE)
RETURN NUMBER IS v_pret_mediu FLOAT := NULL;
    v_cod_companie lant_companii.cod_companie%TYPE;
    exc_fara_televizat EXCEPTION;
    BEGIN
        SELECT cod_companie INTO v_cod_companie
        FROM lant_companii
        WHERE lower(v_nume_companie) = lower(nume_companie);
        
        -- calculez pretul mediu in functie de toate contractele televizate aflate in desfasurare
        BEGIN
            SELECT ROUND(SUM(t.difuzare_int1*60/t.durata_spot*pt.cost_int1 + t.difuzare_int2*60/t.durata_spot*pt.cost_int2) / 
                         SUM(t.difuzare_int1 + t.difuzare_int2)) 
            INTO v_pret_mediu
            FROM televizat t, post_tv pt, campanii_marketing cm
            WHERE t.cod_tv = pt.cod_tv
                AND t.cod_marketing = cm.cod_marketing
                AND cm.cod_companie = v_cod_companie
                AND cm.finalizare - SYSDATE >0
            GROUP BY cm.cod_companie;
            EXCEPTION 
                WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20080, 'Nu exista contracte televizate in desfasurare!');
        END;
        RETURN v_pret_mediu;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20081, 'Nu exista magazinul introdus!');
END ex_8;

-- <<Exercitiul 9>>

--      Sa se afiseze pentru cel mai performant magazin X din fiecare localitate (cea mai mare cifra de afaceri) informatii 
-- legate de campaniile offline desfasurate de companie.

FUNCTION cel_mai_bun(v_cod_companie IN spatii_comerciale.cod_companie%TYPE, v_cod_localitate IN spatii_comerciale.cod_localitate%TYPE)
RETURN spatii_comerciale.cod_magazin%TYPE IS
v_cod spatii_comerciale.cod_magazin%TYPE := -1;
    BEGIN
        SELECT cod_magazin INTO v_cod 
        FROM spatii_comerciale
        WHERE cifra_vanzari =( 
                                SELECT MAX(cifra_vanzari) 
                                FROM spatii_comerciale
                                WHERE cod_companie = v_cod_companie 
                                    AND cod_localitate = v_cod_localitate);
        RETURN v_cod;
END cel_mai_bun;

PROCEDURE ex_9 
(v_nume_companie IN lant_companii.nume_companie%TYPE)
IS
    v_cod_companie lant_companii.cod_companie%TYPE;
    v_cod_loc localitati.cod_localitate%TYPE;
    v_cod_mag_1 spatii_comerciale.cod_magazin%TYPE;
    v_ca spatii_comerciale.cifra_vanzari%TYPE;
    TYPE rec_marketing IS RECORD(
        nume campanii_marketing.nume_campanie%TYPE,
        nr_rev localitati_tinta.nr_reviste%TYPE,
        nr_pli localitati_tinta.nr_pliante%TYPE,
        nr_pan localitati_tinta.nr_panouri%TYPE
    );
     TYPE tab_marketing IS TABLE OF rec_marketing INDEX BY PLS_INTEGER;
     info_marketing tab_marketing;
    -- selectez localitatile care au magazin(e) de la compania introdusa
    CURSOR loc_mag_comp (v_cod_companie spatii_comerciale.cod_companie%TYPE) IS
        SELECT DISTINCT sc.cod_localitate, l.nume_loc, j.nume_jud 
        FROM spatii_comerciale sc, localitati l, judete j
        WHERE cod_companie = v_cod_companie
            AND sc.cod_localitate = l.cod_localitate
            AND l.cod_judet = j.cod_judet
        ORDER BY j.nume_jud, l.nume_loc;
    -- selectez detalii despre campaniile de marketing desfasurate de compania X in toate localitatile
    CURSOR info_campanii (v_cod_companie spatii_comerciale.cod_companie%TYPE) IS
        SELECT lt.cod_localitate, cm.nume_campanie, nvl(lt.nr_reviste, 0) as rev,  nvl(lt.nr_pliante, 0) as pli, nvl(lt.nr_panouri, 0) as pan
        FROM localitati_tinta lt, camp_offline co, campanii_marketing cm
        WHERE lt.cod_offline = co.cod_offline 
        AND co.cod_marketing = cm.cod_marketing 
        AND cm.cod_companie = v_cod_companie
        AND cm.finalizare - SYSDATE > 0;
BEGIN
    SELECT cod_companie INTO v_cod_companie
    FROM lant_companii
    WHERE lower(v_nume_companie) = lower(nume_companie);
    -- salvez informatiile despre campaniile aflate in desfasurare de compani X in toate localitatile
    FOR mkt IN info_campanii(v_cod_companie) LOOP
        info_marketing(mkt.cod_localitate).nume := mkt.nume_campanie; 
        info_marketing(mkt.cod_localitate).nr_rev := mkt.rev; 
        info_marketing(mkt.cod_localitate).nr_pli := mkt.pli; 
        info_marketing(mkt.cod_localitate).nr_pan := mkt.pan; 
    END LOOP;
    
    FOR loc IN loc_mag_comp(v_cod_companie) LOOP
        v_cod_mag_1 := cel_mai_bun(v_cod_companie, loc.cod_localitate); 
        SELECT cifra_vanzari INTO v_ca FROM spatii_comerciale WHERE cod_magazin = v_cod_mag_1;
        DBMS_OUTPUT.PUT_LINE('<O>'||' '||upper(v_nume_companie) || ' ' || v_cod_mag_1 || ' ' || loc.nume_jud|| ' ' ||loc.nume_loc); 
        DBMS_OUTPUT.PUT_LINE('  # Cifra vanzari: ' || v_ca || ' RON/luna');
        -- afisez info despre campanii de marketing, daca ea exista
        BEGIN
        DBMS_OUTPUT.PUT_LINE('  # Campania: '||upper(info_marketing(loc.cod_localitate).nume)); 
        DBMS_OUTPUT.PUT_LINE('      - Numar reviste: ' || info_marketing(loc.cod_localitate).nr_rev); 
        DBMS_OUTPUT.PUT_LINE('      - Numar pliante: ' || info_marketing(loc.cod_localitate).nr_pli); 
        DBMS_OUTPUT.PUT_LINE('      - Numar panouri publicitare: ' || info_marketing(loc.cod_localitate).nr_pan); 
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('  # NU EXISTA CAMPANIE DE MARKETING AFLATA IN DESFASURARE! '); 
        END;    
    END LOOP;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20090, 'Magazinul introdus nu a fost gasit!');
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20091, 'Exista mai multe magazine cu aceeasi cifra de vanzari!');
        WHEN CURSOR_ALREADY_OPEN THEN
            RAISE_APPLICATION_ERROR(-20092, 'Accesare multipla a aceeasi zona de memorie!');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20093, 'Alta eroare!');
END ex_9;

END pachet_13;

 
-- <<Exercitiul 6>>
execute pachet_13.ex_6('discount','dâmbovita');       
-- <<Exercitiul 7>>
execute pachet_13.ex_7('discount');     
-- <<Exercitiul 8>>
BEGIN
    DBMS_OUTPUT.PUT_LINE(pachet_13.ex_8('kaufland') || ' RON/minut'); 
END;
/
-- <<Exercitiul 9>>
execute pachet_13.ex_9('kaufland');   

