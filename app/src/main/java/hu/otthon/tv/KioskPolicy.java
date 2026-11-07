package hu.otthon.tv;
import android.app.*;
import android.app.admin.DevicePolicyManager;
import android.content.*;
import android.content.pm.*;
import android.os.Build;
import java.util.*;

final class KioskPolicy {
    static DevicePolicyManager manager(Context c){return (DevicePolicyManager)c.getSystemService(Context.DEVICE_POLICY_SERVICE);}
    static ComponentName admin(Context c){return new ComponentName(c,AdminReceiver.class);}
    static boolean owner(Context c){DevicePolicyManager d=manager(c);return d!=null&&d.isDeviceOwnerApp(c.getPackageName());}
    static Set<String> excluded(Context c){
        Set<String> out=new HashSet<>(Arrays.asList("com.android.settings","com.android.tv.settings","com.android.systemui","com.android.packageinstaller","com.google.android.packageinstaller"));
        PackageManager pm=c.getPackageManager();
        for(ResolveInfo ri:pm.queryIntentActivities(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),0))if(!ri.activityInfo.packageName.equals(c.getPackageName()))out.add(ri.activityInfo.packageName);
        for(String action:new String[]{android.provider.Settings.ACTION_SETTINGS,android.provider.Settings.ACTION_HOME_SETTINGS,android.provider.Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS})for(ResolveInfo ri:pm.queryIntentActivities(new Intent(action),0))if(!ri.activityInfo.packageName.equals(c.getPackageName()))out.add(ri.activityInfo.packageName);
        return out;
    }
    static boolean locked(Context c){return ((ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE)).getLockTaskModeState()==ActivityManager.LOCK_TASK_MODE_LOCKED;}
    static void configure(Activity a,List<String> apps){
        if(Build.VERSION.SDK_INT<28||!owner(a))throw new IllegalStateException("A teljes kioszkmódhoz Android 9+ és eszközfelügyelői jogosultság szükséges.");
        ArrayList<String> allow=new ArrayList<>();allow.add(a.getPackageName());Set<String> excluded=excluded(a);
        for(String pkg:apps)if(!excluded.contains(pkg)&&!allow.contains(pkg))allow.add(pkg);
        DevicePolicyManager d=manager(a);ComponentName admin=admin(a);
        d.setLockTaskPackages(admin,allow.toArray(new String[0]));
        d.setLockTaskFeatures(admin,DevicePolicyManager.LOCK_TASK_FEATURE_HOME);
        IntentFilter home=new IntentFilter(Intent.ACTION_MAIN);home.addCategory(Intent.CATEGORY_HOME);home.addCategory(Intent.CATEGORY_DEFAULT);
        d.addPersistentPreferredActivity(admin,home,new ComponentName(a,MainActivity.class));
    }
    static void unlock(Context c){
        c.getSharedPreferences("otthon",0).edit().putBoolean("kiosk",false).commit();
        if(c instanceof Activity){try{((Activity)c).stopLockTask();}catch(Exception ignored){}}
        if(owner(c)){
            DevicePolicyManager d=manager(c);
            d.setLockTaskPackages(admin(c),new String[0]);
            d.clearPackagePersistentPreferredActivities(admin(c),c.getPackageName());
        }
    }
    static void release(Context c){unlock(c);if(owner(c))manager(c).clearDeviceOwnerApp(c.getPackageName());}
}
