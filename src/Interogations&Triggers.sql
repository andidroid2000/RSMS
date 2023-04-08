SET serveroutput ON;

-- <<Exercitiul 6>>

-- Sa se analizeze situatia financiara a unui anumit tip de magazine dintr-un judet (ambele date de utilizator).
-- Pentru fiecare magazin in parte se va prezenta cat la suta reprezinta din cifra totala de afaceri a companiei si detalii generale privind anul deschiderii si suprafata acestuia.


CREATE OR REPLACE PROCEDURE ex_6 
(v_tip_magazin IN lant_companii.tip_magazin%TYPE, v_nume_judet IN judete.nume_jud%TYPE)
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
/
BEGIN
    ex_6('discount','dâmbovita');
END;
/
-- <<Exercitiul 7>>

--      Sa se afiseze pentru magazinele de un anumit tip (discount, constructii, proximitate) situatia actuala
-- a aprovizionarii. Se va calcula pretul aprovizionarii fiecarui magazin, stiind ca marfa de la un centru logistic este impartita
-- in mod egal intre magazine.

CREATE OR REPLACE PROCEDURE ex_7 (v_tip_magazin IN lant_companii.tip_magazin%TYPE) IS
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
/

BEGIN
    ex_7('discount');
END;
/


-- <<Exercitiul 8>>

--      Sa se afiseze pentru o companie x pretul mediu platit per minut pentru publicitate televizata.

CREATE OR REPLACE FUNCTION ex_8(v_nume_companie IN lant_companii.nume_companie%TYPE)
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
/
-- Caz 'Nu exista magazinul introdus!'
BEGIN
   DBMS_OUTPUT.PUT_LINE (ex_8('Carrefour'));
END;
/
-- Caz 'Nu exista contracte televizate in desfasurare!'
BEGIN
   DBMS_OUTPUT.PUT_LINE (ex_8('Lidl'));
END;
/
-- Caz acceptat
BEGIN
   DBMS_OUTPUT.PUT_LINE (ex_8('Kaufland') || ' RON/minut');
END;
/

-- <<Exercitiul 9>>

--      Sa se afiseze pentru cel mai performant magazin X din fiecare localitate (cea mai mare cifra de afaceri) informatii 
-- legate de campaniile offline desfasurate de companie.

CREATE OR REPLACE FUNCTION cel_mai_bun(v_cod_companie IN spatii_comerciale.cod_companie%TYPE, v_cod_localitate IN spatii_comerciale.cod_localitate%TYPE)
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
/

CREATE OR REPLACE PROCEDURE ex_9 
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
/
-- Caz 'Magazinul introdus nu a fost gasit!'
BEGIN
    ex_9('carrefour');
END;
/
-- Caz 'Exista mai multe magazine cu aceeasi cifra de vanzari!'
BEGIN
    ex_9('profi');
END;
/
-- Caz acceptare
BEGIN
    ex_9('kaufland');
END;
/

-- <<Exercitiul 10>> 

--      Defini?i un trigger de tip LMD la nivel de comand?. Declan?a?i trigger-ul.

--      Sa se realizeze un trigger de tip LMD la nivel de comanda care sa verifice ca numarul de distribuitori
-- nu reprezinta mai multe de un sfert din cel al producatorilor (pentru a nu se satura piata trasnportatorilor).

CREATE OR REPLACE TRIGGER ex_10
    BEFORE INSERT ON distribuitor
DECLARE
    pragma autonomous_transaction;
    v_nr_dis INT;
    v_nr_prod INT;
BEGIN
    SELECT COUNT(cod_distribuitor) INTO v_nr_dis FROM distribuitor;
    SELECT COUNT(cod_producator) INTO v_nr_prod FROM producatori;
     IF v_nr_dis > v_nr_prod/4 THEN
        RAISE_APPLICATION_ERROR(-20100,'S-A ATINS NUMARUL MAXIM DE DISTRIBUITORI NECESARI!');
    END IF;
END ex_10;
/

-- Declansare TRIGGER
BEGIN 
    FOR i IN 1 .. 5 LOOP
        INSERT INTO distribuitor VALUES (i*100, 700000, 160, 'Cargurs Marfa');
    END LOOP;
END;
/
-- Sterge trigger
DROP TRIGGER ex_10;
/

-- <<Exercitiul 11>> 
--      Definiti un trigger de tip LMD la nivel de linie. Declansati trigger-ul.

--      Sa se realizeze un trigger de tip LMD la nivel de linie care sa verifice cantitatea de produse cerute in functie 
-- de cea existenta la producator la introducerea si actualizarea contractelor. Pentru stergerea de contracte, se va verifica ca acestea nu
-- se mai afla in desfasurare.

-- functie care verifica disponibilitatea distribuitorilor
CREATE OR REPLACE FUNCTION disponibilitate_distribuitor(v_distribuitor IN distribuitor.cod_distribuitor%TYPE) 
RETURN distribuitor.cantitate_marfa%TYPE IS
liber distribuitor.cantitate_marfa%TYPE := NULL;
BEGIN
    SELECT cantitate_marfa - (SELECT SUM(cantitate_prod) 
                                    FROM contracte 
                                    GROUP BY cod_distribuitor 
                                    HAVING cod_distribuitor = v_distribuitor)
    INTO liber
    FROM distribuitor 
    WHERE cod_distribuitor = v_distribuitor;
    -- tratarea cazului cand distribuitorul e liber
    IF liber is NULL THEN
        SELECT cantitate_marfa INTO liber FROM distribuitor WHERE cod_distribuitor = v_distribuitor;
    END IF;
    RETURN liber;
END disponibilitate_distribuitor;
/
BEGIN
    DBMS_OUTPUT.PUT_LINE(disponibilitate_distribuitor(4));
END;
-- functie care verifica disponibilitatea produselor la furnizori
CREATE OR REPLACE FUNCTION stoc_disponibil(producator IN contracte.cod_producator%TYPE) 
RETURN producatori.cantitate_disponibila%TYPE IS
stoc producatori.cantitate_disponibila%TYPE := NULL;
BEGIN
    SELECT cantitate_disponibila - (SELECT SUM(cantitate_prod) 
                                    FROM contracte 
                                    GROUP BY cod_producator 
                                    HAVING cod_producator = producator)
    INTO stoc
    FROM producatori 
    WHERE cod_producator = producator;
    -- tratarea cazului cand distribuitorul e liber
    IF stoc is NULL THEN
        SELECT cantitate_disponibila INTO stoc FROM producatori WHERE cod_producator = producator;
    END IF;
    RETURN stoc;
END stoc_disponibil;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE(stoc_disponibil(4));
END;

CREATE OR REPLACE TRIGGER ex_11
    BEFORE INSERT OR UPDATE OR DELETE ON contracte
    FOR EACH ROW
DECLARE
  pragma autonomous_transaction;
  exceptie_stoc EXCEPTION;
  exceptie_distribuitor EXCEPTION;
  exceptie_data EXCEPTION;
BEGIN
 -- se verifica ca marfa&distribuitorul sa fie disponibili
    IF INSERTING THEN -- se verifica ca marfa sa fie disponibila

        IF :NEW.cantitate_prod > stoc_disponibil(:NEW.cod_producator) THEN 
            RAISE exceptie_stoc;
        ELSIF :NEW.cantitate_prod > disponibilitate_distribuitor(:NEW.cod_distribuitor) THEN 
            RAISE exceptie_distribuitor;
        END IF;
-- se verifica ca marfa&distribuitorul sa fie disponibili
    ELSIF UPDATING THEN 
    -- cand se schimba producatorul, trebuie sa fie integral disponibilia cantitatea contractata
        IF :OLD.cod_producator != :NEW.cod_producator THEN                             
            IF :NEW.cantitate_prod > stoc_disponibil(:NEW.cod_producator) THEN 
                RAISE exceptie_stoc;
            ELSIF :NEW.cantitate_prod > disponibilitate_distribuitor(:NEW.cod_distribuitor) THEN 
                RAISE exceptie_distribuitor;
            END IF;
    -- cand se pastreaza acelasi producator, se verifica ca diferenta sa fie disponibila
        ELSE
            IF :NEW.cantitate_prod - :OLD.cantitate_prod > stoc_disponibil(:NEW.cod_producator) THEN 
                RAISE exceptie_stoc;
            ELSIF :NEW.cantitate_prod - :OLD.cantitate_prod > disponibilitate_distribuitor(:NEW.cod_distribuitor) THEN 
                RAISE exceptie_distribuitor;
            END IF;
        END IF;
    -- cand se sterg contracte aflate in desfasurare
    ELSIF DELETING THEN
        IF :OLD.INCHEIERE - SYSDATE > 0 THEN
            RAISE exceptie_data;
        END IF;
    END IF;
EXCEPTION
    WHEN exceptie_stoc THEN
      RAISE_APPLICATION_ERROR(-20110,'STOC INDISPONIBIL!');
    WHEN exceptie_distribuitor THEN
      RAISE_APPLICATION_ERROR(-20111,'DISTRIBUITOR OCUPAT!');
    WHEN exceptie_data THEN
      RAISE_APPLICATION_ERROR(-20112,'CONTRACT IN DESFASURARE!');  
END ex_11;
/

-- Verificare TRIGGER

-- Activare INSERT
-- STOC INDISPONIBIL
INSERT INTO CONTRACTE (ID_COMANDA, CANTITATE_PROD, COD_DISTRIBUITOR, COD_PRODUCATOR, COD_LOGISTIC, INCEPERE, INCHEIERE)  
VALUES (101, 112000, 2, 1, 1, to_date('21.10.2020', 'DD/MM/YYYY'), to_date('21.10.2023', 'DD/MM/YYYY')); 
-- DISTRIBUITOR OCUPAT
INSERT INTO CONTRACTE (ID_COMANDA, CANTITATE_PROD, COD_DISTRIBUITOR, COD_PRODUCATOR, COD_LOGISTIC, INCEPERE, INCHEIERE)  
VALUES (102, 50000, 4, 7, 1, to_date('21.10.2020', 'DD/MM/YYYY'), to_date('21.10.2023', 'DD/MM/YYYY')); 

-- Activare UPDATE
-- STOC INDISPONIBIL
UPDATE contracte SET cantitate_prod = 100000 WHERE id_comanda = 3;
-- DISTRIBUITOR OCUPAT
UPDATE contracte SET cantitate_prod = 50000 WHERE id_comanda = 1;
-- Varianta acceptata
UPDATE contracte SET cantitate_prod = 2000 WHERE id_comanda = 1;
SELECT * FROM contracte;

-- Activare DELETE
DELETE FROM contracte WHERE id_comanda = 1;
-- Varianta acceptata
DELETE FROM contracte WHERE id_comanda = 2;
SELECT * FROM contracte;

-- Stergere TRIGGER
DROP TRIGGER ex_11;

-- <<Exercitiul 12>> 
--      Defini?i un trigger de tip LDD. Declan?a?i trigger-ul.

--      Definiti un trigger de tip LDD care sa permita modificarea schemei doar de catre utilizatorul 
-- anditoader. Salvati toate modificarile facute in tabela istoric_user.

CREATE TABLE istoric_admin (
    utilizator VARCHAR(30),
    nume_bd VARCHAR(50),
    eveniment VARCHAR(20),
    nume_obiect VARCHAR(30),
    data_ev DATE
);
/

CREATE OR REPLACE TRIGGER ex_12
    BEFORE CREATE OR DROP OR ALTER ON SCHEMA
BEGIN
    IF USER != UPPER('anditoader') THEN
        RAISE_APPLICATION_ERROR(-20120,'Doar administratorul poate aduce schimbari bazei de date!');
    END IF;
    INSERT INTO istoric_admin VALUES (SYS.LOGIN_USER, SYS.DATABASE_NAME, SYS.SYSEVENT, SYS.DICTIONARY_OBJ_NAME, SYSDATE);
END;
/
-- Verificare TRIGGER
ALTER TABLE date_angajati ADD calificare_necesara VARCHAR(30);
ALTER TABLE date_angajati DROP COLUMN calificare_necesara;
select * from istoric_admin;
ROLLBACK;
/
-- Stergere trigger
DROP TRIGGER ex_12;
