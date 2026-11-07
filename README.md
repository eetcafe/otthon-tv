# Otthon TV 2.1

Magyar Android TV launcher és Windowsos grafikus kezelő. Elsődleges célkészülék: Xiaomi MIBOX3, Android 9.

## Letöltés és használat

Közvetlen letöltés: [Windowsos telepítőcsomag](https://github.com/eetcafe/otthon-tv/raw/refs/heads/main/downloads/Otthon-TV-Windows.zip) · [APK](https://github.com/eetcafe/otthon-tv/raw/refs/heads/main/downloads/Otthon-TV.apk).

A változások a [GitHub Releases](https://github.com/eetcafe/otthon-tv/releases) oldalon olvashatók.

1. Töltsd le a Windowsos csomagot, és csomagold ki az egészet.
2. Indítsd az `INDITAS.cmd` fájlt.
3. Csatlakozz a tévé IP-címére, majd válaszd a **Launcher telepítése / frissítése** gombot.
4. Kipróbálás után válaszd az **Alapértelmezett kezdőképernyő** gombot.

A forráskód ZIP-je önmagában nem a telepítőcsomag: a `windows/` mappában nincs APK. A használatra kész csomagot a Releases oldalról töltsd le.

## Funkciók

- Alkalmazásikonos felület, távirányítós kezelés és óra.
- Öt színtéma, három vagy négy csempe soronként, saját főcím.
- Kedvencek kiválasztása, sorrendezés hosszú OK-nyomással, appok elrejtése.
- Windowsos telepítés, Home-váltás és az előző kezdőképernyő visszaállítása.
- Pipálható alkalmazáseltávolítás, védett rendszerkomponensek és helyi visszaállítási napló.

## Windows kezelő 2.1.2 – Xiaomi Home-javítás

Ha a normál Home-beállítás után a távirányító visszavisz a gyári felületre, a **Xiaomi Home javítása** gomb külön, visszaállítható eljárást kínál. Csak Xiaomi készüléken és az azonosított, engedélyezett Google/Xiaomi gyári Home-alkalmazásra használható.

1. Csatlakozz a boxhoz, majd válaszd a **Xiaomi Home javítása** gombot.
2. A kezelő előbb megnyitja az Otthon TV-t. Csak akkor hagyd jóvá, ha a tévén működik.
3. A kezelő menti a visszaállítási adatokat, majd letiltja (nem törli) az aktív gyári launchert.
4. Próbáld ki a távirányító Home gombját. Ha választó jelenik meg, válaszd az Otthon TV-t és a Mindig lehetőséget.
5. Csak sikeres tévés próba után válassz Igent. A Nem visszaállítja a gyári launchert.

A **Korábbi kezdőképernyő visszaállítása** gomb újra engedélyezi a gyári launchert. Tartsd meg a PC-s ADB-hozzáférést és a helyi naplómappát. Amíg a gyári Home le van tiltva, a tévés Kilépés csempe nem tudja azt megnyitni. A beállítás hibája után a kezelő megpróbál automatikusan visszaállítani; megszakadt kapcsolatnál a naplót megőrzi a következő próbához.

Ez a mód a Home-kezdőképernyő váltására szolgál, nem pótolja a hiányzó Device Owner támogatást. A folyamat és a visszaállítás szimulált ADB-válaszokkal tesztelve; fizikai boxon még nincs igazolva. Az APK továbbra is 2.1.

## Windows kezelő 2.1.1

A **Kioszk ellenőrzése** gomb csak olvas: ellenőrzi az Android-verziót, az `android.software.device_admin` funkciót és a felismerhető Device Owner állapotot. Hiányzó firmware-támogatásnál a kezelő nem próbál jogosultságot beállítani. A generikus `Can't set package ... as device owner` hiba önmagában nem bizonyít fiókproblémát. A rendszer funkciójának hiányát egy launcherfrissítés nem pótolja. A csomag APK-ja továbbra is a 2.1-es verzió; csak a Windowsos kezelőt kell cserélni.

## Kioszkmód és kilépés

A **Kilépés** csempe mindig látható, és nincs PIN-nel védve. Feloldja a kioszkot, majd másik telepített kezdőképernyő vagy a TV beállításai választhatók. Az első indításkor használati útmutató jelenik meg; az **Útmutató** menüből újra megnyitható.

A teljes Android Lock Task kioszkhoz Android 9+ és Device Owner jogosultság kell. A Windowsos kezelő **Kioszk jogosultság beállítása** gombja a felhasználó megerősítése után megpróbálja ezt beállítani. Ez fiókokkal már beállított eszközön elutasítható. A program nem töröl fiókot és nem végez gyári visszaállítást. A tévén az **Útmutató → Kioszkmód** kapcsolja be a tényleges lezárást; a normál mód nem teljes kioszk.

Vészfeloldás: a kezelő **Kioszk feloldása** gombja. A **Felügyelet visszavonása** gomb eltávolítja az Otthon TV Device Owner szerepét. A shell vezérlő broadcastját az Android `DUMP` jogosultsága védi; hétköznapi app nem küldheti. A felügyelet a tévés Kilépés menüből is visszavonható.

A kioszk a megjelenített alkalmazások használatát engedi. A rendszerbeállítások és más Home-alkalmazások kizártak. Ez nem hitelesített, manipulációbiztos vendégterminál: a felhasználó által kért kilépési csempe szándékosan hozzáférhető.

## 2.1 javítások

- Android `--brief` kimenetben a behúzott Home-komponensek felismerése.
- A Home-ellenőrzés hibája nem rejti el az alkalmazáslistát; az eltávolítás ilyenkor külön blokkolt.
- A Visszaállítás a napló nélkül korábban letiltott ismert appokat és az eltávolított rendszerappokat is felismeri.
- Üres állapotok magyarázata és helyi Diagnosztika gomb.
- A csomaglista olvasható akkor is, ha az egyedi készülékazonosító nem kérdezhető le; módosításhoz továbbra is azonosítás kell.

## Korlátok

A launcher nem töröl rendszerappokat önállóan. A Windowsos kezelő engedélyezett ADB-kapcsolatot használ, jelenleg az IP:5555 végponton, a fő (0) felhasználóhoz. A rendszerappok a felhasználótól kerülnek eltávolításra, a rendszerpartíción megmaradnak. A felhasználói appok visszaállításához újratelepítés szükséges. Ismeretlen rendszerappokat nem minősít automatikusan bloatware-nek.

Az alapértelmezett Home-kezelő teljes indításkor és a Home gombbal érhető el. Készenlétből az eszköz folytathatja az előző appot. A TV bekapcsolása nem feltétlenül indítja újra a csatlakoztatott boxot.

A launcher Android 6+ rendszert céloz. Más Xiaomi és Philips modellek kompatibilitása nincs igazolva.

## Fordítás

JDK 17, Android SDK 34 és Gradle 8.7 vagy újabb, AGP 8.6.1-gyel kompatibilis verzió szükséges. A projekt Android Studióban is megnyitható. Gradle wrapper jelenleg nincs a repóban; telepített Gradle-lel:

```sh
gradle :app:assembleDebug
```

Eredmény: `app/build/outputs/apk/debug/app-debug.apk`.

A debug APK más kulccsal készül, mint a korábban terjesztett APK, ezért azt nem tudja helyben frissíteni. Tesztkészüléken használd, vagy saját aláírással készíts kiadást. Az eredeti kiadás aláírókulcsa nincs a repóban.

Saját Windowsos csomaghoz másold az APK-t `windows/Otthon-TV.apk` néven, majd a `windows/Otthon-TV-Kezelo.ps1` fájl `$script:ExpectedHash` értékét frissítsd az APK SHA-256 ellenőrzőösszegére.

## Tesztek és ellenőrzés

PowerShell 7-tel, a repó gyökeréből:

```sh
pwsh -NoProfile -File tests/Core.Tests.ps1
```

A teszt szimulált ADB-válaszokkal ellenőrzi a csomagvédelmet, a készülékcsere blokkolását, az eltávolítás naplózását és a rendszerappok visszaállítását. Nem csatlakozik tévéhez.

A kiadott APK fordítása és aláírása helyben ellenőrizve. A GitHub Actions Gradle-fordítása, Windows PowerShell 5.1 regressziós tesztjei és valódi Windows Forms-listatesztje sikeresen lefutott a 2.1-es forrásra. Az eredmény az Actions lapon látható. A Windows-teszt szimulált ADB-válaszokat használ, nem módosít tévét. Fizikai tévén és valódi Device Owner/Lock Task környezetben a működés még nincs igazolva.

## Felépítés

- `app/`: Android alkalmazás és erőforrások.
- `windows/`: grafikus kezelő, ADB-műveletek, magyar használati útmutató.
- `tests/`: csomagvédelmi és visszaállítási tesztek.

A kezelő nem kér rendszergazdai indítást, és nem változtatja meg tartósan a Windows végrehajtási házirendjét. Naplóit a helyi `%LOCALAPPDATA%\Otthon-TV-Kezelo` mappában tartja.
