package hu.otthon.tv;
import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.*;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;

public class MainActivity extends Activity {
    LinearLayout root,content; SharedPreferences prefs; boolean all=false; boolean guideOpen=false; boolean startingKiosk=false;
    int accent,base,card; final int white=0xfff0f4fb,muted=0xffa6b4c9;
    String focusPackage=null;
    final String[] defaultFavorites={"com.netflix.ninja","com.google.android.youtube.tv","com.disney.disneyplus","com.amazon.amazonvideo.livingroom","org.xbmc.kodi","com.spotify.tv.android"};
    final String[] themes={"Éjféli menta","Óceán","Levendula","Naplemente","Grafit"};
    final int[] accents={0xff67e8c2,0xff6fcaff,0xffc2a6ff,0xffffbe87,0xffeeeeee};
    final int[] bases={0xff091a20,0xff09162b,0xff181127,0xff251a19,0xff14171c};
    public void onCreate(Bundle b){super.onCreate(b);prefs=getSharedPreferences("otthon",MODE_PRIVATE);render(false);getWindow().getDecorView().post(()->entryMessages());}
    @Override protected void onResume(){super.onResume();if(prefs!=null){render(all);getWindow().getDecorView().post(()->resumeKiosk());}}
    @Override protected void onNewIntent(Intent i){super.onNewIntent(i);setIntent(i);all=false;focusPackage=null;render(false);entryMessages();}
    int dp(int v){return Math.round(getResources().getDisplayMetrics().density*v);}
    TextView text(String s,int size,int color){TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(color);return t;}
    GradientDrawable background(int color,boolean selected){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(16));d.setStroke(dp(selected?3:1),selected?accent:0x22ffffff);return d;}
    ArrayList<String> saved(String key,String[] fallback){ArrayList<String> out=new ArrayList<>();try{JSONArray a=new JSONArray(prefs.getString(key,new JSONArray(Arrays.asList(fallback)).toString()));for(int i=0;i<a.length();i++){String s=a.getString(i);if(!out.contains(s))out.add(s);}}catch(Exception e){out.addAll(Arrays.asList(fallback));}return out;}
    void save(String key,List<String> values){prefs.edit().putString(key,new JSONArray(values).toString()).apply();}
    Intent appIntent(String pkg){PackageManager pm=getPackageManager();Intent i=pm.getLeanbackLaunchIntentForPackage(pkg);return i!=null?i:pm.getLaunchIntentForPackage(pkg);}
    String label(String pkg){try{return getPackageManager().getApplicationLabel(getPackageManager().getApplicationInfo(pkg,0)).toString();}catch(Exception e){return pkg;}}
    void toast(String s){Toast.makeText(this,s,Toast.LENGTH_LONG).show();}
    void start(Intent i){if(prefs.getBoolean("kiosk",false)){toast("A rendszerbeállításokhoz előbb nyisd meg a Kilépés csempét.");return;}try{startActivity(i);}catch(Exception e){toast("Ez a művelet ezen a készüléken nem érhető el.");}}
    void open(String pkg){Intent i=appIntent(pkg);if(i!=null){focusPackage=pkg;try{if(prefs.getBoolean("kiosk",false)){if(KioskPolicy.excluded(this).contains(pkg)){toast("Ehhez előbb a Kilépés csempét válaszd.");return;}if(android.os.Build.VERSION.SDK_INT>=28&&KioskPolicy.owner(this)){ActivityOptions options=ActivityOptions.makeBasic();options.setLockTaskEnabled(true);startActivity(i,options.toBundle());}else{toast("A kioszkjogosultság nem érhető el.");}}else startActivity(i);}catch(Exception e){toast("Az alkalmazás nem indítható ebben a módban.");}}else{toast("Ez az alkalmazás már nem érhető el.");render(all);}}
    List<String> installed(){Set<String> names=new HashSet<>();PackageManager pm=getPackageManager();for(String cat:new String[]{Intent.CATEGORY_LEANBACK_LAUNCHER,Intent.CATEGORY_LAUNCHER})for(ResolveInfo ri:pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(cat),0)){String p=ri.activityInfo.packageName;if(!p.equals(getPackageName()))names.add(p);}ArrayList<String> out=new ArrayList<>(names);Collections.sort(out,(a,b)->label(a).compareToIgnoreCase(label(b)));return out;}
    void focusStyle(View v,Runnable action){v.setFocusable(true);v.setFocusableInTouchMode(true);v.setClickable(true);v.setBackground(background(card,false));v.setOnFocusChangeListener((view,f)->{view.setBackground(background(f?blend(card,accent,.14f):card,f));view.animate().scaleX(f?1.035f:1f).scaleY(f?1.035f:1f).setDuration(120).start();});v.setOnClickListener(w->action.run());}
    int blend(int a,int b,float t){return Color.rgb((int)(Color.red(a)*(1-t)+Color.red(b)*t),(int)(Color.green(a)*(1-t)+Color.green(b)*t),(int)(Color.blue(a)*(1-t)+Color.blue(b)*t));}
    TextView pill(String title,Runnable action){TextView v=text(title,14,white);v.setGravity(Gravity.CENTER);v.setPadding(dp(15),dp(10),dp(15),dp(10));focusStyle(v,action);return v;}
    void render(boolean showAll){
        all=showAll;int theme=Math.max(0,Math.min(4,prefs.getInt("theme",0)));accent=accents[theme];base=bases[theme];card=blend(base,Color.WHITE,.065f);
        root=new LinearLayout(this);root.setOrientation(1);root.setPadding(dp(34),dp(20),dp(34),dp(14));root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TL_BR,new int[]{blend(base,accent,.08f),base,0xff090c13}));setContentView(root);
        LinearLayout header=new LinearLayout(this);header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout brand=new LinearLayout(this);brand.setOrientation(1);TextView eyebrow=text("OTTHON  /  TV",11,accent);eyebrow.setLetterSpacing(.15f);brand.addView(eyebrow);TextView title=text(all?"Alkalmazások":prefs.getString("title","A te estéd. A te képernyőd."),26,white);title.setTypeface(null,Typeface.BOLD);brand.addView(title);header.addView(brand,new LinearLayout.LayoutParams(0,-2,1));
        LinearLayout clocks=new LinearLayout(this);clocks.setOrientation(1);clocks.setGravity(Gravity.RIGHT);TextClock clock=new TextClock(this);clock.setFormat24Hour("HH:mm");clock.setFormat12Hour("HH:mm");clock.setTextSize(28);clock.setTextColor(white);clocks.addView(clock);TextClock date=new TextClock(this);date.setFormat24Hour("MMM d., EEE");date.setFormat12Hour("MMM d., EEE");date.setTextSize(12);date.setTextColor(muted);clocks.addView(date);header.addView(clocks);root.addView(header);
        LinearLayout nav=new LinearLayout(this);nav.setPadding(0,dp(16),0,dp(18));
        String[] titles={all?"Kedvencek":"Összes app","Testreszabás","Útmutató","Karbantartás"};Runnable[] actions={()->{focusPackage=null;render(!all);},()->customize(),()->guide(),()->maintenance()};
        for(int i=0;i<titles.length;i++){TextView p=pill(titles[i],actions[i]);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,dp(42));lp.setMargins(0,0,dp(10),0);nav.addView(p,lp);}root.addView(nav);
        LinearLayout section=new LinearLayout(this);TextView sectionName=text(all?"MINDEN ALKALMAZÁS":"KEDVENCEID",12,accent);sectionName.setLetterSpacing(.1f);section.addView(sectionName,new LinearLayout.LayoutParams(0,-2,1));TextView hint=text("OK: indítás  ·  OK hosszan: rendezés",12,muted);section.addView(hint);root.addView(section);
        ScrollView scroll=new ScrollView(this);scroll.setClipToPadding(false);scroll.setPadding(dp(6),dp(10),dp(6),dp(12));content=new LinearLayout(this);content.setOrientation(1);scroll.addView(content);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        List<String> hidden=saved("hidden",new String[]{}),apps=all?installed():saved("favorites",defaultFavorites);ArrayList<String> visible=new ArrayList<>();for(String p:apps)if(!hidden.contains(p)&&appIntent(p)!=null&&(!prefs.getBoolean("kiosk",false)||!KioskPolicy.excluded(this).contains(p)))visible.add(p);visible.add("@exit");
        int columns=prefs.getInt("columns",4)==3?3:4;View first=null,wanted=null;
        for(int n=0;n<visible.size();n+=columns){LinearLayout row=new LinearLayout(this);for(int c=0;c<columns;c++){int pos=n+c;LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(118),1);lp.setMargins(dp(5),dp(5),dp(5),dp(5));if(pos<visible.size()){String pkg=visible.get(pos);View tile=pkg.equals("@exit")?exitTile():appTile(pkg);row.addView(tile,lp);if(first==null)first=tile;if(pkg.equals(focusPackage))wanted=tile;}else row.addView(new Space(this),lp);}content.addView(row);}
        if(visible.isEmpty()){TextView empty=text("Még nincs itt alkalmazás.\nA Testreszabás menüben választhatsz kedvenceket.",19,muted);empty.setPadding(dp(12),dp(28),dp(12),dp(28));content.addView(empty);}
        TextView footer=text("Otthon TV 2.1   •   "+(prefs.getBoolean("kiosk",false)?"KIOSZKMÓD · feloldás: Kilépés csempe":(all?"Vissza: kedvencek":"Normál mód · kioszk: Útmutató")),11,muted);root.addView(footer);
        if(wanted!=null)wanted.requestFocus();else if(first!=null)first.requestFocus();else nav.getChildAt(0).requestFocus();
    }
    View appTile(String pkg){LinearLayout tile=new LinearLayout(this);tile.setOrientation(1);tile.setGravity(Gravity.CENTER);tile.setPadding(dp(10),dp(10),dp(10),dp(8));ImageView icon=new ImageView(this);try{icon.setImageDrawable(getPackageManager().getApplicationIcon(pkg));}catch(Exception e){}icon.setScaleType(ImageView.ScaleType.FIT_CENTER);tile.addView(icon,new LinearLayout.LayoutParams(dp(52),dp(52)));TextView name=text(label(pkg),15,white);name.setGravity(Gravity.CENTER);name.setMaxLines(1);name.setEllipsize(android.text.TextUtils.TruncateAt.END);LinearLayout.LayoutParams np=new LinearLayout.LayoutParams(-1,-2);np.topMargin=dp(8);tile.addView(name,np);tile.setContentDescription(label(pkg));focusStyle(tile,()->open(pkg));tile.setOnLongClickListener(v->{focusPackage=pkg;appMenu(pkg);return true;});return tile;}
    void appMenu(String pkg){ArrayList<String> fav=saved("favorites",defaultFavorites);boolean pinned=fav.contains(pkg);new AlertDialog.Builder(this).setTitle(label(pkg)).setItems(new String[]{pinned?"Kivétel a kedvencekből":"Hozzáadás a kedvencekhez","Előrébb a kedvencek között","Hátrébb a kedvencek között","Elrejtés a launcherben","Alkalmazás rendszerbeállításai"},(d,which)->{if(which==0){if(pinned)fav.remove(pkg);else fav.add(pkg);save("favorites",fav);}else if(which==1||which==2){int i=fav.indexOf(pkg),j=i+(which==1?-1:1);if(i>=0&&j>=0&&j<fav.size()){Collections.swap(fav,i,j);save("favorites",fav);}else toast("A kedvencek között ezen az irányon nem mozgatható tovább.");}else if(which==3){ArrayList<String> h=saved("hidden",new String[]{});if(!h.contains(pkg))h.add(pkg);save("hidden",h);}else{start(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+pkg)));return;}render(all);}).setNegativeButton("Mégse",null).show();}
    void customize(){new AlertDialog.Builder(this).setTitle("Legyen a tiéd").setItems(new String[]{"Színtéma és háttér","Kedvencek kiválasztása","Elrejtett alkalmazások","Csempeméret","Főcím átírása","Alapértelmezett kezdőképernyő"},(d,w)->{switch(w){case 0:new AlertDialog.Builder(this).setTitle("Színtéma").setSingleChoiceItems(themes,prefs.getInt("theme",0),(a,i)->{prefs.edit().putInt("theme",i).apply();a.dismiss();render(all);}).setNegativeButton("Mégse",null).show();break;case 1:chooseApps(false);break;case 2:chooseApps(true);break;case 3:new AlertDialog.Builder(this).setTitle("Csempeméret").setSingleChoiceItems(new String[]{"Nagy – 3 egy sorban","Kompakt – 4 egy sorban"},prefs.getInt("columns",4)==3?0:1,(a,i)->{prefs.edit().putInt("columns",i==0?3:4).apply();a.dismiss();render(all);}).show();break;case 4:EditText input=new EditText(this);input.setSingleLine(true);input.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(42)});input.setText(prefs.getString("title","A te estéd. A te képernyőd."));new AlertDialog.Builder(this).setTitle("Saját főcím").setView(input).setPositiveButton("Mentés",(a,i)->{String s=input.getText().toString().trim();prefs.edit().putString("title",s.isEmpty()?"Otthon TV":s).apply();render(all);}).setNegativeButton("Mégse",null).show();break;case 5:homeSettings();}}).setNegativeButton("Bezárás",null).show();}
    void chooseApps(boolean hiding){List<String> apps=installed();ArrayList<String> current=saved(hiding?"hidden":"favorites",hiding?new String[]{}:defaultFavorites);String[] labels=new String[apps.size()];boolean[] checks=new boolean[apps.size()];for(int i=0;i<apps.size();i++){labels[i]=label(apps.get(i));checks[i]=current.contains(apps.get(i));}new AlertDialog.Builder(this).setTitle(hiding?"Pipa = elrejtve":"Kedvenc alkalmazások").setMultiChoiceItems(labels,checks,(d,i,checked)->checks[i]=checked).setPositiveButton("Mentés",(d,w)->{ArrayList<String> result=new ArrayList<>();for(String p:current){int i=apps.indexOf(p);if(i>=0&&checks[i])result.add(p);}for(int i=0;i<apps.size();i++)if(checks[i]&&!result.contains(apps.get(i)))result.add(apps.get(i));save(hiding?"hidden":"favorites",result);render(all);}).setNegativeButton("Mégse",null).show();}
    void homeSettings(){Intent query=new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);ResolveInfo ri=getPackageManager().resolveActivity(query,PackageManager.MATCH_DEFAULT_ONLY);boolean ours=ri!=null&&ri.activityInfo!=null&&getPackageName().equals(ri.activityInfo.packageName);new AlertDialog.Builder(this).setTitle(ours?"Az Otthon TV az alapértelmezett":"Automatikus kezdőképernyő").setMessage(ours?"A Home gomb és a rendszer kezdőképernyő-indítása ide vezet. Készenlétből a készülék visszatérhet a legutóbbi alkalmazáshoz.":"A Windowsos Otthon TV Kezelőben válaszd az Alapértelmezett kezdőképernyő gombot. A rendszer beállításait is megpróbálhatod megnyitni.").setPositiveButton("Rendszerbeállítások",(d,w)->start(new Intent(Settings.ACTION_HOME_SETTINGS))).setNegativeButton("Bezárás",null).show();}
    void maintenance(){new AlertDialog.Builder(this).setTitle("Alkalmazások és takarítás").setMessage("Appok elrejtése: Testreszabás → Elrejtett alkalmazások.\n\nA rendszerappok eltávolításához indítsd el a PC-n az Otthon TV Kezelőt. Ott pipákkal választhatsz, és vissza is állíthatod a rendszerappokat.\n\nA tévés alkalmazás önmagában nem rendelkezik rendszerappok törlési jogosultságával.").setPositiveButton("TV alkalmazásbeállításai",(d,w)->start(new Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS))).setNegativeButton("Bezárás",null).show();}

    View exitTile(){
        LinearLayout tile=new LinearLayout(this);tile.setOrientation(1);tile.setGravity(Gravity.CENTER);
        TextView symbol=text("↗",38,accent);symbol.setGravity(Gravity.CENTER);tile.addView(symbol,new LinearLayout.LayoutParams(dp(52),dp(56)));
        TextView title=text("Kilépés",15,white);title.setGravity(Gravity.CENTER);tile.addView(title);
        tile.setContentDescription("Kilépés és a kioszkmód feloldása");focusStyle(tile,()->exitMenu());return tile;
    }
    void entryMessages(){
        String message=prefs.getString("control_message","");
        if(!message.isEmpty()){prefs.edit().remove("control_message").apply();new AlertDialog.Builder(this).setTitle("Kioszkvezérlés").setMessage(message).setPositiveButton("Rendben",null).show();}
        else if(!prefs.getBoolean("guide_21",false))guide();
    }
    void guide(){
        if(guideOpen)return;guideOpen=true;
        AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Üdv az Otthon TV-ben!").setMessage(
            "Nyilak: választás. OK: alkalmazás indítása.\n\nOK hosszan: kedvencek, sorrend és elrejtés. A Testreszabás menüben színtémát, csempeméretet és saját főcímet választhatsz.\n\nA Kilépés csempe mindig látható: feloldja a kioszkot és megnyithatod a régi főképernyőt. A Vissza gomb a launcheren belül marad.\n\nA Home és az alkalmazásváltó teljes korlátozásához Android 9+ és a Windowsos kezelőben beállított kioszkjogosultság kell. A normál mód nem teljes lezárás.\n\nA Windowsos kezelő Kioszk feloldása gombja vészfeloldásra használható. A felügyelet később visszavonható.")
            .setPositiveButton("Értem",(d,w)->prefs.edit().putBoolean("guide_21",true).apply())
            .setNeutralButton("Kioszkmód",(d,w)->{prefs.edit().putBoolean("guide_21",true).apply();kioskDialog();}).create();
        dialog.setOnDismissListener(d->guideOpen=false);dialog.show();
    }
    void kioskDialog(){
        if(prefs.getBoolean("kiosk",false)){new AlertDialog.Builder(this).setTitle("Kioszkmód bekapcsolva").setMessage("A feloldáshoz a Kilépés csempét válaszd.").setPositiveButton("Rendben",null).show();return;}
        if(android.os.Build.VERSION.SDK_INT<28||!KioskPolicy.owner(this)){
            new AlertDialog.Builder(this).setTitle("Kioszkjogosultság szükséges").setMessage("A teljes lezáráshoz Android 9+ kell. A PC kezelőjében válaszd a Kioszk jogosultság beállítása gombot. Meglévő Google-fiókok mellett az Android elutasíthatja ezt. Nem törlünk fiókot és nem végzünk gyári visszaállítást.\n\nAddig a normál Home-kezdőképernyő használható, teljes lezárás nélkül.").setPositiveButton("Rendben",null).show();return;
        }
        new AlertDialog.Builder(this).setTitle("Kioszkmód bekapcsolása?").setMessage("A Home ide tér vissza, az alkalmazásváltó és a rendszerbeállítások korlátozottak lesznek. A megjelenített appokat használhatod.\n\nFeloldás: Kilépés csempe → Feloldás és kilépés. A PC kezelőjéből is feloldható. A kilépést nem védi PIN.")
            .setPositiveButton("Bekapcsolás",(d,w)->{prefs.edit().putBoolean("kiosk",true).apply();resumeKiosk();})
            .setNegativeButton("Mégse",null).show();
    }
    void resumeKiosk(){
        if(!prefs.getBoolean("kiosk",false)||startingKiosk)return;
        startingKiosk=true;
        try{KioskPolicy.configure(this,installed());if(!KioskPolicy.locked(this))startLockTask();render(all);
            getWindow().getDecorView().postDelayed(()->{startingKiosk=false;if(prefs.getBoolean("kiosk",false)&&!KioskPolicy.locked(this)){try{KioskPolicy.unlock(this);}catch(Exception ignored){}toast("A rendszer nem igazolta a kioszkmódot. Normál módban maradsz.");render(all);}},500);
        }catch(Exception e){startingKiosk=false;try{KioskPolicy.unlock(this);}catch(Exception ignored){}prefs.edit().putBoolean("kiosk",false).apply();toast("A kioszkmód nem indult el: "+e.getMessage());render(all);}
    }
    void exitMenu(){new AlertDialog.Builder(this).setTitle("Kilépés").setMessage("Feloldhatod a kioszkot, és választhatsz másik főképernyőt. A Home alapértelmezése ettől még Otthon TV maradhat.")
        .setPositiveButton("Feloldás és kilépés",(d,w)->{try{KioskPolicy.unlock(this);render(false);chooseExitHome();}catch(Exception e){toast("A feloldás nem sikerült: "+e.getMessage());}})
        .setNeutralButton("Felügyelet visszavonása",(d,w)->new AlertDialog.Builder(this).setTitle("Kioszkfelügyelet visszavonása?").setMessage("A valódi kioszkmód később csak a Windowsos jogosultságbeállítás után használható újra.").setPositiveButton("Visszavonás",(x,y)->{try{KioskPolicy.release(this);toast("A felügyelet visszavonva.");render(false);}catch(Exception e){toast(e.getMessage());}}).setNegativeButton("Mégse",null).show())
        .setNegativeButton("Maradok",null).show();}
    void chooseExitHome(){
        PackageManager pm=getPackageManager();ArrayList<ResolveInfo> homes=new ArrayList<>();
        for(ResolveInfo ri:pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),0))if(!ri.activityInfo.packageName.equals(getPackageName()))homes.add(ri);
        String[] names=new String[homes.size()+1];for(int i=0;i<homes.size();i++)names[i]=homes.get(i).loadLabel(pm).toString();names[homes.size()]="TV beállításai";
        new AlertDialog.Builder(this).setTitle("Hová lépsz ki?").setItems(names,(d,w)->{if(w==homes.size())start(new Intent(Settings.ACTION_SETTINGS));else{ResolveInfo ri=homes.get(w);start(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).setComponent(new ComponentName(ri.activityInfo.packageName,ri.activityInfo.name)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));}}).setNegativeButton("Vissza",null).show();
    }
    @Override public void onBackPressed(){if(all){focusPackage=null;render(false);}}
}
