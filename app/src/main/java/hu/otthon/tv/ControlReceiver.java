package hu.otthon.tv;
import android.content.*;
// Exported for the ADB shell only; Android enforces the signature-level DUMP permission.
public class ControlReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c,Intent intent){
        String action=intent.getAction(),message;
        if(!"hu.otthon.tv.UNLOCK".equals(action)&&!"hu.otthon.tv.RELEASE_OWNER".equals(action))return;
        try{
            if("hu.otthon.tv.RELEASE_OWNER".equals(action)){KioskPolicy.release(c);message=KioskPolicy.owner(c)?"A felügyelet megmaradt; próbáld a tévés Kilépés menüből.":"A kioszkfelügyelet visszavonva.";}
            else{KioskPolicy.unlock(c);message="A kioszkmód feloldva.";}
        }catch(Exception e){message="A kioszk feloldása nem sikerült: "+e.getMessage();}
        c.getSharedPreferences("otthon",0).edit().putString("control_message",message).apply();
        c.startActivity(new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TOP));
    }
}
