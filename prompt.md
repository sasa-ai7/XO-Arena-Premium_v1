com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity,
unregisterSystemUIBroadcastReceiver failed java.lang.IllegalArgumentException: Receiver not registered:
android.view.OplusScrollToTopManager$2@d669b1f
[        ] W/WindowOnBackDispatcher(  951): sendCancelIfRunning: isInProgress=false
callback=android.view.ViewRootImpl$$ExternalSyntheticLambda13@98b1d6a
[        ] D/HWUI    (  951): RenderProxy::destroy: this=0xb4000071f9978f00, mContext=0xb400007122885580
[        ] D/HWUI    (  951): SkiaVulkanPipeline::setSurface: this=0xb40000711defd3c0, surface=NULL
[        ] D/BLASTBufferQueue(  951): [VRI[SignInHubActivity]#4](f:0,a:1) destructor()
[        ] D/BufferQueueConsumer(  951): [VRI[SignInHubActivity]#4(BLAST Consumer)4](id:3b700000004,api:0,p:-1,c:951)
disconnect
[        ] D/ViewRootImpl(  951): Skipping stats log for color mode
[        ] D/InsetsController(  951): hide(ime(), fromIme=false)
[        ] I/ImeTracker(  951): com.xoarena.neonclash:36676e2b: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
[        ] D/InsetsController(  951): hide(ime(), fromIme=false)
[        ] I/ImeTracker(  951): com.xoarena.neonclash:4492baca: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
[ +302 ms] I/flutter (  951): [AUTH] STEP 2 OK: Google authentication credentials obtained
[   +1 ms] I/flutter (  951): [AUTH] STEP 3: signInWithCredential
[  +68 ms] W/System  (  951): Ignoring header X-Firebase-Locale because its value was null.
[ +207 ms] W/LocalRequestInterceptor(  951): Error getting App Check token; using placeholder token instead. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[ +310 ms] D/OplusScrollToTopManager(  951): com.xoarena.neonclash/com.xoarena.neonclash.MainActivity,This
com.android.internal.policy.DecorView{f060132 V.E...... R....... 0,0-720,1604 aid=0 alpha=1.0 viewInfo = }[MainActivity]
change focus to true
[+1270 ms] W/System  (  951): Ignoring header X-Firebase-Locale because its value was null.
[ +200 ms] W/LocalRequestInterceptor(  951): Error getting App Check token; using placeholder token instead. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[ +736 ms] W/arena.neonclash(  951): Verification of void
com.google.android.gms.internal.firebase-auth-api.zzre.zza(boolean) took 126.882ms (2994.89 bytecodes/s) (0B arena
alloc)
[+1638 ms] D/FirebaseAuth(  951): Notifying id token listeners about user ( eFwcg5i92LT2K34lPjlIVIhxje63 ).
[   +2 ms] D/FirebaseAuth(  951): Notifying auth state listeners about user ( eFwcg5i92LT2K34lPjlIVIhxje63 ).
[  +87 ms] I/flutter (  951): [AUTH] STEP 3 OK: signInWithCredential
[   +1 ms] I/flutter (  951): [AUTH] Google photoUrl:
https://lh3.googleusercontent.com/a/ACg8ocLsCHce_QOewSlxcap7xXlLwrpCDbAxe69_TgQD18RJw-GDjw=s96-c, Firebase photoURL:
https://lh3.googleusercontent.com/a/ACg8ocLsCHce_QOewSlxcap7xXlLwrpCDbAxe69_TgQD18RJw-GDjw=s96-c
[        ] I/flutter (  951): [AUTH] STEP 4: Checking if profile exists in Firestore
[ +506 ms] W/DynamiteModule(  951): Local module descriptor class for com.google.android.gms.providerinstaller.dynamite
not found.
[  +55 ms] I/DynamiteModule(  951): Considering local module com.google.android.gms.providerinstaller.dynamite:0 and
remote module com.google.android.gms.providerinstaller.dynamite:0
[   +1 ms] W/ProviderInstaller(  951): Failed to load providerinstaller module: No acceptable module
com.google.android.gms.providerinstaller.dynamite found. Local version is 0 and remote version is 0.
[  +48 ms] D/ApplicationLoaders(  951): Returning zygote-cached class loader:
/system/framework/org.apache.http.legacy.jar
[   +8 ms] D/ApplicationLoaders(  951): Returning zygote-cached class loader:
/system/framework/com.android.location.provider.jar
[        ] D/ApplicationLoaders(  951): Returning zygote-cached class loader:
/system/framework/com.android.media.remotedisplay.jar
[   +4 ms] W/arena.neonclash(  951): Cleared Reference was only reachable from finalizer (only reported once)
[  +47 ms] D/nativeloader(  951): Configuring clns-10 for other apk
/system_ext/framework/com.android.extensions.appfunctions.jar. target_sdk_version=37, uses_libraries=ALL,
library_path=/data/app/~~6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/lib/arm64:/data/app/~~
6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/base.apk!/lib/arm64-v8a,
permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
[   +1 ms] D/nativeloader(  951): Extending system_exposed_libraries:
libapuwareapusys.mtk.so:libapuwareapusys_v2.mtk.so:libapuwarexrp.mtk.so:libapuwarexrp_v2.mtk.so:libapuwareutils.mtk.so:l
ibapuwareutils_v2.mtk.so:libapuwarehmp.mtk.so:libapuwareaiste.mtk.so:libneuron_graph_delegate.mtk.so:libneuronusdk_adapt
er.mtk.so:libtflite_mtk.mtk.so:libarmnn_ndk.mtk.so:libcmdl_ndk.mtk.so:libnir_neon_driver_ndk.mtk.so:libmvpu_runtime.mtk.
so:libmvpu_runtime_pub.mtk.so:libmvpu_engine_pub.mtk.so:libmvpu_pattern_pub.mtk.so:libmvpuop_mtk_cv.mtk.so:libmvpuop_mtk
_nn.mtk.so:libmvpu_runtime_25.mtk.so:libmvpu_runtime_25_pub.mtk.so:libmvpu_engine_25_pub.mtk.so:libmvpu_pattern_25_pub.m
tk.so:libmvpuop25_mtk_cv.mtk.so:libmvpuop25_mtk_nn.mtk.so:libmvpu_config.mtk.so:libmvpu_engine_30.mtk.so:libmvpu_pattern
_30.mtk.so:libmvpu_cic_ci_compiler_30.mtk.so:libmvpu_runtime_30.mtk.so:libmvpu_clc_30_mvpu_debuginfo.mtk.so:libmvpu_clc_
30_mvpu_elf.mtk.so:libmvpu_clc_30_mvpu_utility.mtk.so:libneuronservice_adapter.mtk.so:libneuron_sys_util.mtk.so:libmvpuo
p30_mtk_nn.mtk.so:libneuron
[        ] D/ApplicationLoaders(  951): Returning zygote-cached class loader:
/system_ext/framework/androidx.window.extensions.jar
[        ] D/ApplicationLoaders(  951): Returning zygote-cached class loader:
/system_ext/framework/androidx.window.sidecar.jar
[  +21 ms] I/arena.neonclash(  951): Background young concurrent mark compact GC freed 4126KB AllocSpace bytes,
20(880KB) LOS objects, 51% free, 4588KB/9466KB, paused 1.288ms,6.063ms total 158.281ms
[  +56 ms] D/HWUI    (  951): SkiaVulkanPipeline::setSurface: this=0xb40000711defd3c0, surface=NULL
[ +196 ms] D/nativeloader(  951): Configuring clns-11 for other apk
/data/app/~~6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/base.apk. target_sdk_version=37,
uses_libraries=,
library_path=/data/app/~~6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/lib/arm64:/data/app/~~
6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/base.apk!/lib/arm64-v8a,
permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
[  +91 ms] I/arena.neonclash(  951): AssetManager2(0xb40000725526d428) locale list changing from [] to [en-US]
[  +30 ms] I/arena.neonclash(  951): hiddenapi: Accessing hidden method
Ldalvik/system/VMStack;->getStackClass2()Ljava/lang/Class; (runtime_flags=0, domain=core-platform, api=unsupported) from
Lhfxt; (domain=app, TargetSdkVersion=35) using reflection: allowed
[  +97 ms] E/GoogleApiManager(  951): Failed to get service from broker.
[   +1 ms] E/GoogleApiManager(  951): java.lang.SecurityException: Unknown calling package name
'com.google.android.gms'.
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.createExceptionOrNull(Parcel.java:3369)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.createException(Parcel.java:3353)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.readException(Parcel.java:3336)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.readException(Parcel.java:3278)
[        ] E/GoogleApiManager(  951):   at bjqy.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):36)
[        ] E/GoogleApiManager(  951):   at bjou.z(:com.google.android.gms@261934035@26.19.34 (260400-919740205):143)
[        ] E/GoogleApiManager(  951):   at biuq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):42)
[        ] E/GoogleApiManager(  951):   at android.os.Handler.handleCallback(Handler.java:1027)
[        ] E/GoogleApiManager(  951):   at android.os.Handler.dispatchMessage(Handler.java:108)
[        ] E/GoogleApiManager(  951):   at dbbh.mJ(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] E/GoogleApiManager(  951):   at dbbh.dispatchMessage(:com.google.android.gms@261934035@26.19.34
(260400-919740205):5)
[        ] E/GoogleApiManager(  951):   at android.os.Looper.loopOnce(Looper.java:302)
[        ] E/GoogleApiManager(  951):   at android.os.Looper.loop(Looper.java:412)
[        ] E/GoogleApiManager(  951):   at android.os.HandlerThread.run(HandlerThread.java:85)
[   +1 ms] W/GoogleApiManager(  951): Not showing notification since connectionResult is not user-facing:
ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[   +4 ms] D/nativeloader(  951): Load
/data/app/~~6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/base.apk!/lib/arm64-v8a/libconscryp
t_gmscore_jni.so using class loader ns clns-11
(caller=/data/app/~~6I_0aId-kAnjqa_wyi9sxQ==/com.google.android.gms-LY2cWk6C3rb9-GtPJUEgWg==/base.apk): ok
[   +6 ms] V/NativeCrypto(  951): Registering com/google/android/gms/org/conscrypt/NativeCrypto's 336 native methods...
[   +8 ms] W/FlagRegistrar(  951): Failed to register com.google.android.gms.providerinstaller#com.xoarena.neonclash
[        ] W/FlagRegistrar(  951): glrp: 17: 17: API: Phenotype.API is not available on this device. Connection failed
with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[        ] W/FlagRegistrar(  951):      at glrr.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):13)
[        ] W/FlagRegistrar(  951):      at hlmk.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):3)
[   +1 ms] W/FlagRegistrar(  951):      at hlmm.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):139)
[        ] W/FlagRegistrar(  951):      at hlou.execute(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagRegistrar(  951):      at hlmu.f(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagRegistrar(  951):      at hlmu.m(:com.google.android.gms@261934035@26.19.34 (260400-919740205):101)
[        ] W/FlagRegistrar(  951):      at hlmu.q(:com.google.android.gms@261934035@26.19.34 (260400-919740205):16)
[        ] W/FlagRegistrar(  951):      at gfco.hA(:com.google.android.gms@261934035@26.19.34 (260400-919740205):35)
[        ] W/FlagRegistrar(  951):      at frkq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):12)
[        ] W/FlagRegistrar(  951):      at hlou.execute(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagRegistrar(  951):      at frkr.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):18)
[        ] W/FlagRegistrar(  951):      at frlg.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):34)
[        ] W/FlagRegistrar(  951):      at frli.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):22)
[        ] W/FlagRegistrar(  951):      at birw.e(:com.google.android.gms@261934035@26.19.34 (260400-919740205):9)
[        ] W/FlagRegistrar(  951):      at biuo.q(:com.google.android.gms@261934035@26.19.34 (260400-919740205):48)
[        ] W/FlagRegistrar(  951):      at biuo.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):10)
[        ] W/FlagRegistrar(  951):      at biuo.g(:com.google.android.gms@261934035@26.19.34 (260400-919740205):191)
[        ] W/FlagRegistrar(  951):      at biuo.onConnectionFailed(:com.google.android.gms@261934035@26.19.34
(260400-919740205):2)
[        ] W/FlagRegistrar(  951):      at biuq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):70)
[        ] W/FlagRegistrar(  951):      at android.os.Handler.handleCallback(Handler.java:1027)
[        ] W/FlagRegistrar(  951):      at android.os.Handler.dispatchMessage(Handler.java:108)
[        ] W/FlagRegistrar(  951):      at dbbh.mJ(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagRegistrar(  951):      at dbbh.dispatchMessage(:com.google.android.gms@261934035@26.19.34
(260400-919740205):5)
[   +3 ms] W/FlagRegistrar(  951):      at android.os.Looper.loopOnce(Looper.java:302)
[        ] W/FlagRegistrar(  951):      at android.os.Looper.loop(Looper.java:412)
[        ] W/FlagRegistrar(  951):      at android.os.HandlerThread.run(HandlerThread.java:85)
[        ] W/FlagRegistrar(  951): Caused by: biqb: 17: API: Phenotype.API is not available on this device. Connection
failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[        ] W/FlagRegistrar(  951):      at bjog.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):15)
[        ] W/FlagRegistrar(  951):      at birz.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagRegistrar(  951):      at birw.e(:com.google.android.gms@261934035@26.19.34 (260400-919740205):5)
[        ] W/FlagRegistrar(  951):      ... 12 more
[  +18 ms] W/FlagStore(  951): Unable to update local snapshot for
com.google.android.gms.providerinstaller#com.xoarena.neonclash, may result in stale flags.
[   +1 ms] W/FlagStore(  951): java.util.concurrent.ExecutionException: glrp: 17: 17: API: Phenotype.API is not
available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null,
message=null, clientMethodKey=null}
[        ] W/FlagStore(  951):  at hlmu.j(:com.google.android.gms@261934035@26.19.34 (260400-919740205):21)
[        ] W/FlagStore(  951):  at hlnd.t(:com.google.android.gms@261934035@26.19.34 (260400-919740205):24)
[        ] W/FlagStore(  951):  at hlmu.get(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at hlrj.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):2)
[        ] W/FlagStore(  951):  at hlpz.s(:com.google.android.gms@261934035@26.19.34 (260400-919740205):10)
[        ] W/FlagStore(  951):  at glwz.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at glwd.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):5)
[        ] W/FlagStore(  951):  at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:520)
[        ] W/FlagStore(  951):  at java.util.concurrent.FutureTask.run(FutureTask.java:317)
[        ] W/FlagStore(  951):  at
java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:348)
[        ] W/FlagStore(  951):  at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1154)
[        ] W/FlagStore(  951):  at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:652)
[        ] W/FlagStore(  951):  at java.lang.Thread.run(Thread.java:1564)
[        ] W/FlagStore(  951): Caused by: glrp: 17: 17: API: Phenotype.API is not available on this device. Connection
failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[        ] W/FlagStore(  951):  at glrr.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):13)
[        ] W/FlagStore(  951):  at hlmk.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):3)
[        ] W/FlagStore(  951):  at hlmm.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):139)
[        ] W/FlagStore(  951):  at hlou.execute(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at hlmu.f(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[   +3 ms] W/FlagStore(  951):  at hlmu.m(:com.google.android.gms@261934035@26.19.34 (260400-919740205):101)
[        ] W/FlagStore(  951):  at hlmu.q(:com.google.android.gms@261934035@26.19.34 (260400-919740205):16)
[        ] W/FlagStore(  951):  at gfco.hA(:com.google.android.gms@261934035@26.19.34 (260400-919740205):35)
[        ] W/FlagStore(  951):  at frkq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):12)
[        ] W/FlagStore(  951):  at hlou.execute(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at frkr.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):18)
[        ] W/FlagStore(  951):  at frlg.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):34)
[        ] W/FlagStore(  951):  at frln.B(:com.google.android.gms@261934035@26.19.34 (260400-919740205):17)
[        ] W/FlagStore(  951):  at frki.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):60)
[        ] W/FlagStore(  951):  at hlou.execute(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at frkj.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):8)
[        ] W/FlagStore(  951):  at frlg.b(:com.google.android.gms@261934035@26.19.34 (260400-919740205):34)
[        ] W/FlagStore(  951):  at frli.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):22)
[        ] W/FlagStore(  951):  at birw.e(:com.google.android.gms@261934035@26.19.34 (260400-919740205):9)
[        ] W/FlagStore(  951):  at biuo.q(:com.google.android.gms@261934035@26.19.34 (260400-919740205):48)
[        ] W/FlagStore(  951):  at biuo.d(:com.google.android.gms@261934035@26.19.34 (260400-919740205):10)
[        ] W/FlagStore(  951):  at biuo.g(:com.google.android.gms@261934035@26.19.34 (260400-919740205):191)
[        ] W/FlagStore(  951):  at biuo.onConnectionFailed(:com.google.android.gms@261934035@26.19.34
(260400-919740205):2)
[        ] W/FlagStore(  951):  at biuq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):70)
[        ] W/FlagStore(  951):  at android.os.Handler.handleCallback(Handler.java:1027)
[   +2 ms] W/FlagStore(  951):  at android.os.Handler.dispatchMessage(Handler.java:108)
[        ] W/FlagStore(  951):  at dbbh.mJ(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at dbbh.dispatchMessage(:com.google.android.gms@261934035@26.19.34 (260400-919740205):5)
[        ] W/FlagStore(  951):  at android.os.Looper.loopOnce(Looper.java:302)
[        ] W/FlagStore(  951):  at android.os.Looper.loop(Looper.java:412)
[        ] W/FlagStore(  951):  at android.os.HandlerThread.run(HandlerThread.java:85)
[        ] W/FlagStore(  951): Caused by: biqb: 17: API: Phenotype.API is not available on this device. Connection
failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[        ] W/FlagStore(  951):  at bjog.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):15)
[        ] W/FlagStore(  951):  at birz.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] W/FlagStore(  951):  at birw.e(:com.google.android.gms@261934035@26.19.34 (260400-919740205):5)
[        ] W/FlagStore(  951):  ... 12 more
[  +38 ms] I/arena.neonclash(  951): hiddenapi: Accessing hidden method
Ljava/security/spec/ECParameterSpec;->getCurveName()Ljava/lang/String; (runtime_flags=0, domain=core-platform,
api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform; (domain=app, TargetSdkVersion=35) using
reflection: allowed
[  +95 ms] I/ProviderInstaller(  951): Installed default security provider GmsCore_OpenSSL
[ +612 ms] I/arena.neonclash(  951): hiddenapi: Accessing hidden field Ljava/net/Socket;->impl:Ljava/net/SocketImpl;
(runtime_flags=0, domain=core-platform, api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform;
(domain=app, TargetSdkVersion=35) using reflection: allowed
[ +168 ms] I/arena.neonclash(  951): hiddenapi: Accessing hidden method
Ljava/security/spec/ECParameterSpec;->setCurveName(Ljava/lang/String;)V (runtime_flags=0, domain=core-platform,
api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform; (domain=app, TargetSdkVersion=35) using
reflection: allowed
[ +483 ms] I/arena.neonclash(  951): Background concurrent mark compact GC freed 3043KB AllocSpace bytes, 1(548KB) LOS
objects, 51% free, 5863KB/11MB, paused 1.203ms,9.762ms total 118.118ms
[  +80 ms] I/flutter (  951): [AUTH] STEP 5: saveUserToFirestore
[+1250 ms] I/flutter (  951): [AUTH] STEP 5 OK: saveUserToFirestore
[   +4 ms] I/flutter (  951): [AUTH] STEP 6: syncToLocalStore
[  +89 ms] I/flutter (  951): [AUTH] STEP 6 OK: syncToLocalStore
[   +3 ms] I/flutter (  951): [AUTH] STEP 7: userRepo.initAfterAuth
[   +3 ms] I/flutter (  951): [AUTH] UserRepo: initAfterAuth start
[+3407 ms] I/flutter (  951): [AUTH] UserRepo: pullServerToLocal start
[ +264 ms] I/flutter (  951): [AUTH] UserRepo: pullServerToLocal success uid=eFwcg5i92LT2K34lPjlIVIhxje63
[   +2 ms] I/flutter (  951): [REFERRAL] ensureCode start uid=eFwcg5i92LT2K34lPjlIVIhxje63
[ +147 ms] I/flutter (  951): [REFERRAL] code already=792490832
[   +1 ms] I/flutter (  951): [AUTH] STEP 7 OK: userRepo.initAfterAuth
[   +4 ms] I/flutter (  951): [AUTH] Login status saved to SharedPreferences
[ +258 ms] I/flutter (  951): [SESSION] Written session 1780107541560 for eFwcg5i92LT2K34lPjlIVIhxje63 on Realme RMX5020
[+2357 ms] I/flutter (  951): [PROFILE] no equipped avatar — showing profile image only
[ +588 ms] E/GoogleApiManager(  951): Failed to get service from broker.
[   +1 ms] E/GoogleApiManager(  951): java.lang.SecurityException: Unknown calling package name
'com.google.android.gms'.
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.createExceptionOrNull(Parcel.java:3369)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.createException(Parcel.java:3353)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.readException(Parcel.java:3336)
[        ] E/GoogleApiManager(  951):   at android.os.Parcel.readException(Parcel.java:3278)
[        ] E/GoogleApiManager(  951):   at bjqy.a(:com.google.android.gms@261934035@26.19.34 (260400-919740205):36)
[        ] E/GoogleApiManager(  951):   at bjou.z(:com.google.android.gms@261934035@26.19.34 (260400-919740205):143)
[        ] E/GoogleApiManager(  951):   at biuq.run(:com.google.android.gms@261934035@26.19.34 (260400-919740205):42)
[        ] E/GoogleApiManager(  951):   at android.os.Handler.handleCallback(Handler.java:1027)
[        ] E/GoogleApiManager(  951):   at android.os.Handler.dispatchMessage(Handler.java:108)
[        ] E/GoogleApiManager(  951):   at dbbh.mJ(:com.google.android.gms@261934035@26.19.34 (260400-919740205):1)
[        ] E/GoogleApiManager(  951):   at dbbh.dispatchMessage(:com.google.android.gms@261934035@26.19.34
(260400-919740205):5)
[        ] E/GoogleApiManager(  951):   at android.os.Looper.loopOnce(Looper.java:302)
[        ] E/GoogleApiManager(  951):   at android.os.Looper.loop(Looper.java:412)
[        ] E/GoogleApiManager(  951):   at android.os.HandlerThread.run(HandlerThread.java:85)
[        ] W/GoogleApiManager(  951): Not showing notification since connectionResult is not user-facing:
ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
[ +441 ms] D/WindowOnBackDispatcher(  951):  predictive settings is disabled for com.xoarena.neonclash
[   +1 ms] W/WindowOnBackDispatcher(  951): OnBackInvokedCallback is not enabled for the application.
[        ] W/WindowOnBackDispatcher(  951): Set 'android:enableOnBackInvokedCallback="true"' in the application
manifest.
[  +70 ms] I/flutter (  951): [PROFILE] no equipped avatar — showing profile image only
[ +325 ms] I/flutter (  951): [MUSIC] init triggered from HomeHub
[  +43 ms] I/flutter (  951): [NOTIF] Timezone initialized: Africa/Cairo
[ +259 ms] D/AudioManager(  951): setMode mode=0 from com.xoarena.neonclash
[   +1 ms] I/AudioManager(  951): In setSpeakerphoneOn(), on: false, calling application: com.xoarena.neonclash
[        ] I/flutter (  951): [MUSIC] prefs loaded — musicEnabled=true musicVolume=0.7
[        ] I/flutter (  951): [NOTIF] channel created (daily_reminder, high importance, vibration)
[        ] I/flutter (  951): [NOTIF] init complete
[ +197 ms] I/flutter (  951): [MUSIC] init complete — starting music: true
[   +7 ms] I/flutter (  951): [MUSIC] lifecycle: AppLifecycleState.inactive — playerState=PlayerState.stopped
musicEnabled=true
[ +204 ms] I/flutter (  951): [MUSIC] start requested — volume=0.7
[   +7 ms] I/flutter (  951): [AVATAR_ANALYSIS] using hardcoded override for assets/avatar/Avatar__10.gif
[        ] I/flutter (  951): [IAP] starting after AppMode.online
[  +12 ms] D/VRI[MainActivity](  951): onFocusEvent false
[ +402 ms] D/MediaPlayer(  951): MediaPlayer
[   +1 ms] D/AudioSystem(  951): onNewServiceWithAdapter: media.audio_flinger service obtained 0xb4000071d95e9320
[   +3 ms] D/AudioSystem(  951): getService: IAudioFlingerService retrieved: 0xb40000711da237c0  IAudioFlinger cached:
0xb4000071d95e9320
[  +34 ms] V/MediaPlayer(  951): resetDrmState:  mDrmInfo=null mDrmProvisioningThread=null mPrepareDrmInProgress=false
mActiveDrmScheme=false
[   +1 ms] V/MediaPlayer(  951): cleanDrmObj: mDrmObj=null mDrmSessionId=null
[ +311 ms] I/flutter (  951): [IAP] Found 2 past purchases
[   +1 ms] I/flutter (  951): [IAP] === Processing Purchase ===
[        ] I/flutter (  951): [IAP]   productId=xo_avatar_premium1 isAvatar=true
[        ] I/flutter (  951): [IAP]   orderId=GPA.3349-6672-1612-69655
[        ] I/flutter (  951): [IAP]   baseCoins=0 bonusCoins=0 totalCoins=0
[  +58 ms] D/CompatChangeReporter(  951): Compat change id reported: 311402873; UID 10460; state: ENABLED
[   +1 ms] D/CompatChangeReporter(  951): Compat change id reported: 323349338; UID 10460; state: ENABLED
[ +279 ms] D/OplusScrollToTopManager(  951): com.xoarena.neonclash/com.xoarena.neonclash.MainActivity,This
com.android.internal.policy.DecorView{f060132 V.E...... R....... 0,0-720,1604 aid=0 alpha=1.0 viewInfo = }[MainActivity]
change focus to false
[ +361 ms] I/flutter (  951): [IAP_LOG] purchase_orders updated status=purchased_client_reported
productId=xo_avatar_premium1 orderId=GPA.3349-6672-1612-69655
purchaseTokenHash=cd9eb8e544a2752e8d13aa8e831ca7be868ba33721723c5d3a2d8586084c0e47 txId=order_GPA_3349-6672-1612-69655
[  +34 ms] I/flutter (  951): [VerificationService] Calling Cloud Function for verification...
[   +1 ms] I/flutter (  951): [VerificationService] productId: xo_avatar_premium1
[        ] I/flutter (  951): [VerificationService] purchaseToken: nljcngpgfjeekelldgdc...
[        ] I/flutter (  951): [VerificationService] orderId: GPA.3349-6672-1612-69655
[        ] I/flutter (  951): [VerificationService] packageName: com.xoarena.neonclash
[  +78 ms] W/System  (  951): Ignoring header X-Firebase-Locale because its value was null.
[ +448 ms] W/LocalRequestInterceptor(  951): Error getting App Check token; using placeholder token instead. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[ +385 ms] E/arena.neonclash(  951): QUEUE_BUFFER_TIMEOUT: surfaceName: b460092
SurfaceView[com.xoarena.neonclash/com.xoarena.neonclash, fenceName: GPU completion, lastDuration: 3, waitFenceTime: 122
[ +569 ms] D/FirebaseAuth(  951): Notifying id token listeners about user ( eFwcg5i92LT2K34lPjlIVIhxje63 ).
[  +42 ms] I/flutter (  951): [VerificationService] Calling Cloud Function with data: {productId: xo_avatar_premium1,
purchaseToken:
nljcngpgfjeekelldgdckjbb.AO-J1OwpdkspvpgEAbOXKehaogrzX9V2WTuxw1JvrnVMrYBoPGLJhypUJQaAN3ISp8XvkpkFSLw8VJMTg-FSEIRy7vo6Q4h
GAomyhmbpPHONlN04aCeourw, packageName: com.xoarena.neonclash, orderId: GPA.3349-6672-1612-69655}
[ +347 ms] W/FirebaseContextProvider(  951): Error getting App Check token. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[   +4 ms] D/CompatChangeReporter(  951): Compat change id reported: 270674727; UID 10460; state: ENABLED
[   +2 ms] I/arena.neonclash(  951): Background young concurrent mark compact GC freed 4278KB AllocSpace bytes,
35(1788KB) LOS objects, 43% free, 6777KB/11MB, paused 1.723ms,26.290ms total 299.921ms
[ +612 ms] I/flutter (  951): [VerificationService] Cloud Function error:
[   +1 ms] I/flutter (  951): [VerificationService]   code: not-found
[        ] I/flutter (  951): [VerificationService]   message: NOT_FOUND
[        ] I/flutter (  951): [IAP] Server verification failed. Falling back to local grant.
[ +720 ms] D/ActivityThread(  951): ComponentInfo{com.xoarena.neonclash/com.xoarena.neonclash.MainActivity}
checkFinished=false 4
[   +1 ms] D/ResourcesManagerExtImpl(  951): applyConfigurationToAppResourcesLocked app.getDisplayId() return
callback.displayId:0
[        ] V/AutofillClientController(  951): onActivityResumed()
[        ] V/AutofillClientController(  951): onActivityPostResumed()
[        ] V/AutofillClientController(  951): onActivityPostResumed(): Relayout fix enabled
[        ] V/AutofillClientController(  951): forResume(): Not attempting refill.
[   +1 ms] I/flutter (  951): [NOTIF] permission result: granted=true
[        ] D/VRI[MainActivity](  951): onFocusEvent true
[        ] I/flutter (  951): [MUSIC] lifecycle: AppLifecycleState.resumed — playerState=PlayerState.playing
musicEnabled=true
[        ] I/flutter (  951): [MUSIC] resumed — resuming music
[  +67 ms] D/InsetsController(  951): hide(ime(), fromIme=false)
[   +3 ms] I/ImeTracker(  951): com.xoarena.neonclash:bfa47653: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
[  +20 ms] I/flutter (  951): [NOTIF] permission result: granted=true
[ +258 ms] I/flutter (  951): [NOTIF] Scheduled daily at 2026-05-30 21:00:00.000+0300 — 1 pending request(s)
[ +572 ms] D/OplusScrollToTopManager(  951): com.xoarena.neonclash/com.xoarena.neonclash.MainActivity,This
com.android.internal.policy.DecorView{f060132 V.E...... R....... 0,0-720,1604 aid=0 alpha=1.0 viewInfo = }[MainActivity]
change focus to true
[+1078 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1000 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +27 ms] I/PowerHalMgrImpl(  951): hdl:114, pid:951
[ +115 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +338 ms] D/WindowOnBackDispatcher(  951):  predictive settings is disabled for com.xoarena.neonclash
[   +1 ms] W/WindowOnBackDispatcher(  951): OnBackInvokedCallback is not enabled for the application.
[        ] W/WindowOnBackDispatcher(  951): Set 'android:enableOnBackInvokedCallback="true"' in the application
manifest.
[ +528 ms] I/PowerHalMgrImpl(  951): hdl:115, pid:951
[ +596 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +9 ms] I/PowerHalMgrImpl(  951): hdl:117, pid:951
[  +90 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +707 ms] I/flutter (  951): [INVENTORY_SYNC] addOwnedAvatar → 10
[   +1 ms] I/flutter (  951): [CoinsRepo] Marked purchase as processed: xo_avatar_premium1
[ +228 ms] I/PowerHalMgrImpl(  951): hdl:118, pid:951
[ +123 ms] I/arena.neonclash(  951): Background concurrent mark compact GC freed 4030KB AllocSpace bytes, 18(808KB) LOS
objects, 49% free, 6823KB/13MB, paused 2.679ms,16.236ms total 498.606ms
[+1026 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +3 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +3 ms] I/PowerHalMgrImpl(  951): hdl:120, pid:951
[ +205 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[  +20 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +781 ms] I/PowerHalMgrImpl(  951): hdl:121, pid:951
[ +133 ms] I/flutter (  951): [REFERRAL] ensureCode start uid=eFwcg5i92LT2K34lPjlIVIhxje63
[ +650 ms] I/flutter (  951): [REFERRAL] code already=792490832
[   +9 ms] I/flutter (  951): [WALLET] applying delta source=avatar_purchase delta=0 before=? after=?
[   +4 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +2 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +24 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[        ] I/PowerHalMgrImpl(  951): hdl:123, pid:951
[ +305 ms] I/Choreographer(  951): Skipped 34 frames!  The application may be doing too much work on its main thread.
[   +1 ms] I/flutter (  951): [WALLET_LEDGER] created transactionId=GPA.3349-6672-1612-69655 type=debit
source=avatar_purchase delta=0
[ +204 ms] I/flutter (  951): [WALLET_LEDGER] Firestore ledger write success
[   +1 ms] I/flutter (  951): [IAP] === Processing Purchase ===
[        ] I/flutter (  951): [IAP]   productId=xo_avatar_premium isAvatar=true
[        ] I/flutter (  951): [IAP]   orderId=GPA.3336-6179-3097-45136
[        ] I/flutter (  951): [IAP]   baseCoins=0 bonusCoins=0 totalCoins=0
[ +226 ms] W/Firestore(  951): (26.1.0) [WriteStream]: (9453f0) Stream closed with status:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}.
[  +33 ms] W/Firestore(  951): (26.1.0) [Firestore]: Write failed at purchase_orders/order_GPA_3336-6179-3097-45136:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
[  +13 ms] I/flutter (  951): [IAP_LOG] _logStatus(purchased_client_reported) error: [cloud_firestore/permission-denied]
The caller does not have permission to execute the specified operation.
[        ] I/flutter (  951): [VerificationService] Calling Cloud Function for verification...
[        ] I/flutter (  951): [VerificationService] productId: xo_avatar_premium
[        ] I/flutter (  951): [VerificationService] purchaseToken: fglnkdpbpacgboahpllh...
[        ] I/flutter (  951): [VerificationService] orderId: GPA.3336-6179-3097-45136
[        ] I/flutter (  951): [VerificationService] packageName: com.xoarena.neonclash
[  +20 ms] W/System  (  951): Ignoring header X-Firebase-Locale because its value was null.
[ +126 ms] W/LocalRequestInterceptor(  951): Error getting App Check token; using placeholder token instead. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[  +56 ms] I/PowerHalMgrImpl(  951): hdl:123, pid:951
[ +209 ms] D/FirebaseAuth(  951): Notifying id token listeners about user ( eFwcg5i92LT2K34lPjlIVIhxje63 ).
[  +80 ms] I/flutter (  951): [VerificationService] Calling Cloud Function with data: {productId: xo_avatar_premium,
purchaseToken:
fglnkdpbpacgboahpllhboae.AO-J1OzxiMWkUXcGxhYdD5N39kdodkNbZPFnkZhYtFs0BEuTye-byVCiwWE-722z3bUqBRm5tVP9Pjr5bZ6aQsxuCEV1FE4
iuLaoBI6s2Xd_ZUnDLdps6UM, packageName: com.xoarena.neonclash, orderId: GPA.3336-6179-3097-45136}
[   +1 ms] W/FirebaseContextProvider(  951): Error getting App Check token. Error:
com.google.firebase.FirebaseException: No AppCheckProvider installed.
[ +240 ms] I/flutter (  951): [VerificationService] Cloud Function error:
[   +1 ms] I/flutter (  951): [VerificationService]   code: not-found
[        ] I/flutter (  951): [VerificationService]   message: NOT_FOUND
[        ] I/flutter (  951): [IAP] Server verification failed. Falling back to local grant.
[  +70 ms] W/Firestore(  951): (26.1.0) [WriteStream]: (9453f0) Stream closed with status:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}.
[  +18 ms] W/Firestore(  951): (26.1.0) [Firestore]: Write failed at audit_logs/mXon3eVZyy5J4O8UOC8G:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
[   +1 ms] I/flutter (  951): [AUDIT] permission-denied, queue cleared
[  +34 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] I/PowerHalMgrImpl(  951): hdl:125, pid:951
[  +81 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[  +11 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +147 ms] W/Firestore(  951): (26.1.0) [WriteStream]: (9453f0) Stream closed with status:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}.
[  +22 ms] W/Firestore(  951): (26.1.0) [Firestore]: Write failed at purchase_orders/order_GPA_3336-6179-3097-45136:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
[ +183 ms] I/Choreographer(  951): Skipped 42 frames!  The application may be doing too much work on its main thread.
[ +586 ms] I/PowerHalMgrImpl(  951): hdl:126, pid:951
[ +159 ms] W/Firestore(  951): (26.1.0) [WriteStream]: (9453f0) Stream closed with status:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}.
[  +12 ms] W/Firestore(  951): (26.1.0) [Firestore]: Write failed at purchase_orders/order_GPA_3336-6179-3097-45136:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
[ +954 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] I/PowerHalMgrImpl(  951): hdl:128, pid:951
[  +94 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +603 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +86 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[  +16 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +186 ms] I/PowerHalMgrImpl(  951): hdl:128, pid:951
[  +77 ms] I/flutter (  951): [INVENTORY_SYNC] addOwnedAvatar → 7
[  +14 ms] I/flutter (  951): [CoinsRepo] Marked purchase as processed: xo_avatar_premium
[ +487 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[ +102 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[  +25 ms] I/PowerHalMgrImpl(  951): hdl:131, pid:951
[ +395 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +83 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +7 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +388 ms] I/PowerHalMgrImpl(  951): hdl:131, pid:951
[ +176 ms] W/Firestore(  951): (26.1.0) [WriteStream]: (9453f0) Stream closed with status:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}.
[  +25 ms] W/Firestore(  951): (26.1.0) [Firestore]: Write failed at purchase_orders/order_GPA_3336-6179-3097-45136:
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
[   +9 ms] I/flutter (  951): [IAP_LOG] logCfMirror error: [cloud_firestore/permission-denied] The caller does not have
permission to execute the specified operation.
[   +2 ms] I/flutter (  951): [WALLET] applying delta source=avatar_purchase delta=0 before=? after=?
[  +21 ms] I/flutter (  951): [WALLET_LEDGER] created transactionId=GPA.3336-6179-3097-45136 type=debit
source=avatar_purchase delta=0
[ +294 ms] I/PowerHalMgrImpl(  951): hdl:133, pid:951
[ +427 ms] I/flutter (  951): [WALLET_LEDGER] Firestore ledger write success
[   +1 ms] I/flutter (  951): [IAP] Finished consuming pending purchases
[ +337 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[        ] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[   +2 ms] I/PowerHalMgrImpl(  951): hdl:136, pid:951
[ +868 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[ +112 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +3 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[  +18 ms] I/PowerHalMgrImpl(  951): hdl:138, pid:951
[ +880 ms] I/PowerHalMgrImpl(  951): hdl:139, pid:951
[ +195 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[        ] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[        ] I/PowerHalMgrImpl(  951): hdl:142, pid:951
[+1018 ms] I/PowerHalMgrImpl(  951): hdl:142, pid:951
[+19666 ms] I/arena.neonclash(  951): Background young concurrent mark compact GC freed 6005KB AllocSpace bytes,
13(644KB) LOS objects, 50% free, 6798KB/13MB, paused 2.123ms,5.969ms total 70.840ms
[+7233 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +8 ms] I/PowerHalMgrImpl(  951): hdl:144, pid:951
[ +117 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +889 ms] I/PowerHalMgrImpl(  951): hdl:145, pid:951
[ +383 ms] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__1.png
[   +1 ms] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar_2.png
[   +1 ms] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__3.png
[   +8 ms] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__4.png
[        ] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__5.png
[        ] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__6.png
[        ] I/flutter (  951): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__9.png
[ +721 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[  +11 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +6 ms] I/PowerHalMgrImpl(  951): hdl:147, pid:951
[  +60 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +677 ms] I/Choreographer(  951): Skipped 82 frames!  The application may be doing too much work on its main thread.
[ +144 ms] I/TRuntime.CctTransportBackend(  951): Making request to:
https://firebaselogging.googleapis.com/v0cc/log/batch?format=json_proto3
[  +27 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__1.png center=(0.506, 0.488) r=0.250
[  +18 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__3.png center=(0.498, 0.451) r=0.248
[  +67 ms] I/PowerHalMgrImpl(  951): hdl:148, pid:951
[ +185 ms] I/TRuntime.CctTransportBackend(  951): Status Code: 200
[  +56 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar_2.png center=(0.498, 0.430) r=0.246
[  +22 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__5.png center=(0.498, 0.459) r=0.256
[   +1 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__9.png center=(0.498, 0.434) r=0.250
[        ] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__6.png center=(0.498, 0.490) r=0.246
[ +388 ms] I/flutter (  951): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__4.png center=(0.506, 0.490) r=0.265
[ +305 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +9 ms] I/PowerHalMgrImpl(  951): hdl:150, pid:951
[ +177 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +324 ms] I/flutter (  951): [INVENTORY_SYNC] addOwnedAvatar → 7
[  +58 ms] D/WindowOnBackDispatcher(  951):  predictive settings is disabled for com.xoarena.neonclash
[   +1 ms] W/WindowOnBackDispatcher(  951): OnBackInvokedCallback is not enabled for the application.
[        ] W/WindowOnBackDispatcher(  951): Set 'android:enableOnBackInvokedCallback="true"' in the application
manifest.
[ +449 ms] I/PowerHalMgrImpl(  951): hdl:151, pid:951
[+3621 ms] I/flutter (  951): [INVENTORY_SYNC] addOwnedAvatar → 10
[+3976 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[        ] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[   +1 ms] I/PowerHalMgrImpl(  951): hdl:155, pid:951
[ +425 ms] I/Choreographer(  951): Skipped 51 frames!  The application may be doing too much work on its main thread.
[ +257 ms] I/flutter (  951): [NOTIF] permission result: granted=true
[  +61 ms] I/flutter (  951): [NOTIF] Scheduled daily at 2026-05-30 21:00:00.000+0300 — 1 pending request(s)
[   +1 ms] I/flutter (  951): [NOTIF] Startup reschedule: daily reminder re-armed
[ +258 ms] I/PowerHalMgrImpl(  951): hdl:155, pid:951
[ +112 ms] I/flutter (  951): [MUSIC] init triggered from HomeHub
[ +732 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] I/PowerHalMgrImpl(  951): hdl:157, pid:951
[  +71 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +927 ms] I/PowerHalMgrImpl(  951): hdl:158, pid:951
[+1936 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +4 ms] I/PowerHalMgrImpl(  951): hdl:160, pid:951
[  +84 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +925 ms] I/PowerHalMgrImpl(  951): hdl:161, pid:951
[ +473 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] I/PowerHalMgrImpl(  951): hdl:163, pid:951
[  +97 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +904 ms] I/PowerHalMgrImpl(  951): hdl:164, pid:951
[ +110 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +1 ms] I/PowerHalMgrImpl(  951): hdl:166, pid:951
[  +83 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +230 ms] D/WindowOnBackDispatcher(  951):  predictive settings is disabled for com.xoarena.neonclash
[   +1 ms] W/WindowOnBackDispatcher(  951): OnBackInvokedCallback is not enabled for the application.
[        ] W/WindowOnBackDispatcher(  951): Set 'android:enableOnBackInvokedCallback="true"' in the application
manifest.
[ +179 ms] I/flutter (  951): [REFERRAL] ensureCode start uid=eFwcg5i92LT2K34lPjlIVIhxje63
[  +37 ms] I/flutter (  951): [REFERRAL] code already=792490832
[ +483 ms] I/PowerHalMgrImpl(  951): hdl:167, pid:951
[ +272 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +2 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +6 ms] I/PowerHalMgrImpl(  951): hdl:169, pid:951
[ +107 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +898 ms] I/PowerHalMgrImpl(  951): hdl:170, pid:951
[ +130 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +7 ms] I/PowerHalMgrImpl(  951): hdl:172, pid:951
[  +87 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +918 ms] I/PowerHalMgrImpl(  951): hdl:173, pid:951
[ +578 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +6 ms] I/PowerHalMgrImpl(  951): hdl:175, pid:951
[ +107 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +897 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +15 ms] I/PowerHalMgrImpl(  951): hdl:177, pid:951
[   +2 ms] I/PowerHalMgrImpl(  951): hdl:178, pid:951
[  +68 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +863 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +25 ms] I/PowerHalMgrImpl(  951): hdl:178, pid:951
[  +77 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +534 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +56 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +320 ms] I/PowerHalMgrImpl(  951): hdl:178, pid:951
[ +636 ms] I/PowerHalMgrImpl(  951): hdl:181, pid:951
[ +528 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] I/PowerHalMgrImpl(  951): hdl:183, pid:951
[ +128 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +6 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +886 ms] I/PowerHalMgrImpl(  951): hdl:184, pid:951
[ +846 ms] I/flutter (  951): [ARENA] created room code=237945
[ +701 ms] W/RepoOperation(  951): onDisconnect().setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63
failed: DatabaseError: Permission denied
[   +1 ms] W/RepoOperation(  951): onDisconnect().setValue at /rooms/237945/_hostLeftAt failed: DatabaseError:
Permission denied
[  +13 ms] D/FirebaseDatabase(  951): 🔍 Kotlin: Setting up query observe for path=rooms/237945
[  +10 ms] I/arena.neonclash(  951): Background concurrent mark compact GC freed 5712KB AllocSpace bytes, 20(976KB) LOS
objects, 49% free, 7183KB/14MB, paused 1.381ms,9.848ms total 184.866ms
[ +161 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5114 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+1440 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +9 ms] I/PowerHalMgrImpl(  951): hdl:186, pid:951
[ +105 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +897 ms] I/PowerHalMgrImpl(  951): hdl:187, pid:951
[   +1 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[        ] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +4 ms] I/PowerHalMgrImpl(  951): hdl:189, pid:951
[  +78 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +929 ms] I/PowerHalMgrImpl(  951): hdl:190, pid:951
[+1507 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5135 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+4866 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5013 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+4994 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5025 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+4968 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+3259 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[        ] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[        ] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[   +8 ms] I/PowerHalMgrImpl(  951): hdl:193, pid:951
[+1010 ms] I/PowerHalMgrImpl(  951): hdl:194, pid:951
[ +223 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +4 ms] I/PowerHalMgrImpl(  951): hdl:196, pid:951
[  +91 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +214 ms] W/RepoOperation(  951): updateChildren at /rooms/237945 failed: DatabaseError: Permission denied
[ +184 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[  +37 ms] I/flutter (  951): [ARENA_KICK] update failed: [firebase_database/unknown] Firebase Database error:
Permission denied
[ +477 ms] I/PowerHalMgrImpl(  951): hdl:197, pid:951
[+3944 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +4 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[   +4 ms] I/PowerHalMgrImpl(  951): hdl:200, pid:951
[ +525 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[ +185 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +33 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +225 ms] W/RepoOperation(  951): updateChildren at /rooms/237945 failed: DatabaseError: Permission denied
[  +33 ms] I/PowerHalMgrImpl(  951): hdl:202, pid:951
[ +128 ms] I/flutter (  951): [ARENA_KICK] update failed: [firebase_database/unknown] Firebase Database error:
Permission denied
[ +596 ms] I/PowerHalMgrImpl(  951): hdl:203, pid:951
[+1624 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +10 ms] I/PowerHalMgrImpl(  951): hdl:205, pid:951
[  +79 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +878 ms] D/FirebaseDatabase(  951): 🔍 Kotlin: Setting up query observe for path=rooms/237945
[  +13 ms] D/FirebaseDatabase(  951): 🔍 Kotlin: Setting up query observe for path=.info/connected
[  +45 ms] I/PowerHalMgrImpl(  951): hdl:206, pid:951
[   +8 ms] I/flutter (  951): [ARENA] countdown started room=237945
[  +44 ms] W/RepoOperation(  951): onDisconnect().setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63
failed: DatabaseError: Permission denied
[  +39 ms] W/RepoOperation(  951): onDisconnect().setValue at /rooms/237945/_hostLeftAt failed: DatabaseError:
Permission denied
[  +47 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[  +10 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[ +610 ms] I/flutter (  951): [WALLET] applying delta source=friend_room_bet_entry delta=-500 before=6601 after=6101
[  +25 ms] I/flutter (  951): [WALLET_LEDGER] created
transactionId=arena_237945_1780107626278_eFwcg5i92LT2K34lPjlIVIhxje63_bet_eFwcg5i92LT2K34lPjlIVIhxje63 type=debit
source=friend_room_bet_entry delta=-500
[  +39 ms] I/arena.neonclash(  951): Background young concurrent mark compact GC freed 7027KB AllocSpace bytes, 4(208KB)
LOS objects, 49% free, 7259KB/14MB, paused 3.891ms,6.550ms total 62.224ms
[ +540 ms] I/flutter (  951): [WALLET_LEDGER] Firestore ledger write success
[ +191 ms] I/flutter (  951): [ARENA_BET] debit success uid=eFwcg5i92LT2K34lPjlIVIhxje63 amount=500
[   +7 ms] I/flutter (  951): [ARENA_BET] locked bet uid=eFwcg5i92LT2K34lPjlIVIhxje63 amount=500 prizePool=1000
[+1848 ms] I/flutter (  951): [ARENA] game started room=237945
[ +371 ms] I/flutter (  951): [ARENA_BET] both bets locked code=237945 prizePool=1000
[+1461 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5031 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+5013 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
[+2049 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +2 ms] I/PowerHalMgrImpl(  951): hdl:208, pid:951
[  +45 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +1 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +298 ms] I/flutter (  951): [ARENA] move uid=eFwcg5i92LT2K34lPjlIVIhxje63 cell=0 committed=true
[ +665 ms] I/PowerHalMgrImpl(  951): hdl:208, pid:951
[+1931 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+1824 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[   +6 ms] I/PowerHalMgrImpl(  951): hdl:210, pid:951
[  +65 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[ +892 ms] E/IJankManager(  951): slideSceneEnd unknown scene 1003 mScene:-1
[   +1 ms] V/AutofillManager(  951): requestHideFillUi(null): anchor = null
[  +43 ms] I/PowerHalMgrImpl(  951): hdl:212, pid:951
[  +50 ms] D/OplusViewDragTouchViewHelper(  951): dispatchTouchView action = 1
[   +2 ms] D/ViewRootImplExtImpl(  951): the up motion event handled by client, just return
[  +12 ms] I/flutter (  951): [ARENA] leave requested room=237945 uid=eFwcg5i92LT2K34lPjlIVIhxje63
[ +103 ms] I/flutter (  951): [ARENA_BET] payout check skipped room=237945 self=eFwcg5i92LT2K34lPjlIVIhxje63
winner=TbdqWqYbpaORpWT97MZqO9JrjgV2
[ +249 ms] I/flutter (  951): [ARENA] room finished winner=TbdqWqYbpaORpWT97MZqO9JrjgV2
[   +1 ms] I/flutter (  951): [ARENA] forfeit loser=eFwcg5i92LT2K34lPjlIVIhxje63 winner=TbdqWqYbpaORpWT97MZqO9JrjgV2
[        ] I/flutter (  951): [ARENA] leave success, exiting room=237945
[        ] I/flutter (  951): [ARENA] exit room once room=237945
[ +130 ms] I/flutter (  951): [ARENA] summary result matchId=arena_237945_1780107626278_eFwcg5i92LT2K34lPjlIVIhxje63
self=eFwcg5i92LT2K34lPjlIVIhxje63 savedSelf=true savedGlobal=true
[ +417 ms] I/PowerHalMgrImpl(  951): hdl:213, pid:951
[ +371 ms] W/RepoOperation(  951): setValue at /rooms/237945/playersPresence/eFwcg5i92LT2K34lPjlIVIhxje63 failed:
DatabaseError: Permission denied
[+1816 ms] Service protocol connection closed.
[   +3 ms] Lost connection to device.
[   +1 ms] DevFS: Deleting filesystem on the device
(file:///data/user/0/com.xoarena.neonclash/code_cache/xo-mainLZESSQ/xo-main/)
[   +1 ms] DevFS: Deleted filesystem on the device
(file:///data/user/0/com.xoarena.neonclash/code_cache/xo-mainLZESSQ/xo-main/)
[   +3 ms] "flutter run" took 529,987ms.
[  +31 ms] Running 3 shutdown hooks
[  +15 ms] Shutdown hooks complete
[ +179 ms] exiting with code 0
PS E:\work\xo-main> cd E:\work\xo-main
>>
>> flutter clean
>> flutter pub get
>>
>> flutter devices
>>
>> flutter run -d Q8DQZPHEOJM7OZ4T --verbose
Deleting build...                                                   5.5s
Deleting .dart_tool...                                              16ms
Deleting .flutter-plugins-dependencies...                            1ms
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.66 (1.3.71 available)
  app_links 6.4.1 (7.1.1 available)
  archive 4.0.7 (4.0.9 available)
  async 2.13.0 (2.13.1 available)
  cli_util 0.4.2 (0.5.1 available)
  cloud_firestore 6.1.2 (6.4.1 available)
  cloud_firestore_platform_interface 7.0.6 (8.0.1 available)
  cloud_firestore_web 5.1.2 (5.4.1 available)
  cloud_functions 6.0.7 (6.3.1 available)
  cloud_functions_platform_interface 5.8.10 (6.0.1 available)
  cloud_functions_web 5.1.3 (5.1.7 available)
  code_assets 1.0.0 (1.2.0 available)
  connectivity_plus 6.1.5 (7.1.1 available)
  connectivity_plus_platform_interface 2.0.1 (2.1.0 available)
  dbus 0.7.11 (0.7.13 available)
  device_info_plus 11.5.0 (13.1.0 available)
  device_info_plus_platform_interface 7.0.3 (8.1.0 available)
  ffi 2.1.5 (2.2.0 available)
  firebase_app_check 0.4.1+4 (0.4.4+1 available)
  firebase_app_check_platform_interface 0.2.1+4 (0.4.0+1 available)
  firebase_app_check_web 0.2.2+2 (0.2.4+2 available)
  firebase_auth 6.1.4 (6.5.1 available)
  firebase_auth_platform_interface 8.1.6 (9.0.1 available)
  firebase_auth_web 6.1.2 (6.2.1 available)
  firebase_core 4.5.0 (4.9.0 available)
  firebase_core_platform_interface 6.0.2 (7.0.1 available)
  firebase_core_web 3.5.0 (3.7.0 available)
  firebase_database 12.1.3 (12.4.1 available)
  firebase_database_platform_interface 0.3.0+2 (0.4.0+1 available)
  firebase_database_web 0.2.7+3 (0.2.7+8 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_local_notifications 17.2.4 (21.0.0 available)
  flutter_local_notifications_linux 4.0.1 (8.0.0 available)
  flutter_local_notifications_platform_interface 7.2.0 (11.0.0 available)
  flutter_timezone 3.0.1 (5.1.0 available)
  font_awesome_flutter 10.12.0 (11.0.0 available)
  google_fonts 6.3.3 (8.1.0 available)
  google_sign_in 6.3.0 (7.2.0 available)
  google_sign_in_android 6.2.1 (7.2.11 available)
  google_sign_in_ios 5.9.0 (6.3.0 available)
  google_sign_in_platform_interface 2.5.0 (3.1.0 available)
  google_sign_in_web 0.12.4+4 (1.1.3 available)
  gtk 2.1.0 (2.2.0 available)
  hooks 1.0.2 (2.0.0 available)
  image 4.7.2 (4.9.0 available)
  in_app_purchase_android 0.4.0+8 (0.5.0 available)
  in_app_purchase_storekit 0.4.7 (0.4.9 available)
  json_annotation 4.9.0 (4.12.0 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.17.0 (1.18.2 available)
  native_toolchain_c 0.17.6 (0.19.1 available)
  objective_c 9.3.0 (9.4.1 available)
  package_info_plus 8.3.1 (10.1.0 available)
  package_info_plus_platform_interface 3.2.1 (4.1.0 available)
  petitparser 7.0.1 (7.0.2 available)
  posix 6.0.3 (6.5.0 available)
  share_plus 10.1.4 (13.1.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  shared_preferences 2.5.4 (2.5.5 available)
  shared_preferences_android 2.4.18 (2.4.23 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  source_span 1.10.1 (1.10.2 available)
  sqflite 2.4.2 (2.4.2+1 available)
  sqflite_common 2.5.6 (2.5.8 available)
  synchronized 3.4.0 (3.4.0+1 available)
  test_api 0.7.10 (0.7.12 available)
  timezone 0.9.4 (0.11.0 available)
  url_launcher_android 6.3.28 (6.3.30 available)
  url_launcher_ios 6.3.6 (6.4.1 available)
  url_launcher_web 2.4.1 (2.4.3 available)
  vector_math 2.2.0 (2.3.0 available)
  vm_service 15.0.2 (15.2.0 available)
  win32 5.15.0 (6.3.0 available)
  win32_registry 2.1.0 (3.0.3 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
77 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Found 4 connected devices:
  SM M315F (mobile) • R58N5085HXW • android-arm64  • Android 12 (API 31)
  Windows (desktop) • windows     • windows-x64    • Microsoft Windows [Version 10.0.19045.6466]
  Chrome (web)      • chrome      • web-javascript • Google Chrome 148.0.7778.179
  Edge (web)        • edge        • web-javascript • Microsoft Edge 148.0.3967.83

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may also
try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit https://flutter.dev/setup/
for troubleshooting tips.
[ +250 ms] Artifact Instance of 'MaterialFonts' is not required, skipping update.
[   +3 ms] Artifact Instance of 'GradleWrapper' is not required, skipping update.
[        ] Artifact Instance of 'AndroidGenSnapshotArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'AndroidInternalBuildArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IOSEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterWebSdk' is not required, skipping update.
[   +1 ms] Artifact Instance of 'LegacyCanvasKitRemover' is not required, skipping update.
[        ] Artifact Instance of 'FlutterSdk' is not required, skipping update.
[        ] Artifact Instance of 'WindowsEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'MacOSEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'LinuxEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'LinuxFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'MacOSFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterRunnerSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterRunnerDebugSymbols' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[   +2 ms] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FontSubsetArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'PubDependencies' is not required, skipping update.
[   +1 ms] executing: [E:\Programs\flutter_windows_3.41.6-stable\flutter/] git -c log.showSignature=false log HEAD -n 1
--pretty=format:%ad --date=iso
[  +95 ms] Exit code 0 from: git -c log.showSignature=false log HEAD -n 1 --pretty=format:%ad --date=iso
[   +2 ms] 2026-03-25 16:21:00 -0700
[  +52 ms] Artifact Instance of 'AndroidGenSnapshotArtifacts' is not required, skipping update.
[   +3 ms] Artifact Instance of 'AndroidInternalBuildArtifacts' is not required, skipping update.
[   +1 ms] Artifact Instance of 'IOSEngineArtifacts' is not required, skipping update.
[   +1 ms] Artifact Instance of 'FlutterWebSdk' is not required, skipping update.
[        ] Artifact Instance of 'FlutterEngineStamp' is not required, skipping update.
[   +1 ms] Artifact Instance of 'LegacyCanvasKitRemover' is not required, skipping update.
[   +7 ms] Artifact Instance of 'WindowsEngineArtifacts' is not required, skipping update.
[   +1 ms] Artifact Instance of 'MacOSEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'LinuxEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'LinuxFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'MacOSFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterRunnerSDKArtifacts' is not required, skipping update.
[   +4 ms] Artifact Instance of 'FlutterRunnerDebugSymbols' is not required, skipping update.
[ +131 ms] executing: C:\Users\tatah\AppData\Local\Android\sdk\platform-tools\adb.exe devices -l
[  +93 ms] List of devices attached
           R58N5085HXW            device product:m31nsxx model:SM_M315F device:m31 transport_id:2
[   +9 ms] Artifact Instance of 'MaterialFonts' is not required, skipping update.
[        ] Artifact Instance of 'GradleWrapper' is not required, skipping update.
[        ] Artifact Instance of 'AndroidGenSnapshotArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'AndroidInternalBuildArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IOSEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterWebSdk' is not required, skipping update.
[        ] Artifact Instance of 'FlutterEngineStamp' is not required, skipping update.
[        ] Artifact Instance of 'LegacyCanvasKitRemover' is not required, skipping update.
[        ] Artifact Instance of 'FlutterSdk' is not required, skipping update.
[        ] Artifact Instance of 'WindowsEngineArtifacts' is not required, skipping update.
[   +1 ms] Artifact Instance of 'MacOSEngineArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'LinuxEngineArtifacts' is not required, skipping update.
[   +1 ms] Artifact Instance of 'LinuxFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'MacOSFuchsiaSDKArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FlutterRunnerSDKArtifacts' is not required, skipping update.
[   +3 ms] Artifact Instance of 'FlutterRunnerDebugSymbols' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'IosUsbArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'FontSubsetArtifacts' is not required, skipping update.
[        ] Artifact Instance of 'PubDependencies' is not required, skipping update.
[  +17 ms] C:\Users\tatah\AppData\Local\Android\sdk\platform-tools\adb.exe -s R58N5085HXW shell getprop
[ +177 ms] No supported devices found with name or id matching 'Q8DQZPHEOJM7OZ4T'.
[   +1 ms] The following devices were found:
[   +1 ms] ro.hardware = exynos9611
[        ] ro.build.characteristics = phone
[ +123 ms] SM M315F (mobile) • R58N5085HXW • android-arm64  • Android 12 (API 31)
[   +2 ms] Windows (desktop) • windows     • windows-x64    • Microsoft Windows [Version 10.0.19045.6466]
[        ] Chrome (web)      • chrome      • web-javascript • Google Chrome 148.0.7778.179
[        ] Edge (web)        • edge        • web-javascript • Microsoft Edge 148.0.3967.83
[   +7 ms] "flutter run" took 626ms.
[  +81 ms]
           #0      throwToolExit (package:flutter_tools/src/base/common.dart:34:3)
           #1      RunCommand.validateCommand (package:flutter_tools/src/commands/run.dart:673:7)
           <asynchronous suspension>
           #2      FlutterCommand.verifyThenRunCommand (package:flutter_tools/src/runner/flutter_command.dart:1912:5)
           <asynchronous suspension>
           #3      FlutterCommand.run.<anonymous closure>
(package:flutter_tools/src/runner/flutter_command.dart:1590:27)
           <asynchronous suspension>
           #4      AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
           <asynchronous suspension>
           #5      CommandRunner.runCommand (package:args/command_runner.dart:212:13)
           <asynchronous suspension>
           #6      FlutterCommandRunner.runCommand.<anonymous closure>
           (package:flutter_tools/src/runner/flutter_command_runner.dart:496:9)
           <asynchronous suspension>
           #7      AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
           <asynchronous suspension>
           #8      FlutterCommandRunner.runCommand (package:flutter_tools/src/runner/flutter_command_runner.dart:431:5)
           <asynchronous suspension>
           #9      FlutterCommandRunner.run.<anonymous closure>
           (package:flutter_tools/src/runner/flutter_command_runner.dart:307:33)
           <asynchronous suspension>
           #10     run.<anonymous closure>.<anonymous closure> (package:flutter_tools/runner.dart:104:11)
           <asynchronous suspension>
           #11     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
           <asynchronous suspension>
           #12     main (package:flutter_tools/executable.dart:103:3)
           <asynchronous suspension>


[   +7 ms] Running 2 shutdown hooks
[   +4 ms] Shutdown hooks complete
[ +257 ms] exiting with code 1
PS E:\work\xo-main> flutter clean
>> flutter pub get
>> flutter run                                                                                                          Deleting .dart_tool...                                               4ms
Deleting .flutter-plugins-dependencies...                            1ms
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.66 (1.3.71 available)
  app_links 6.4.1 (7.1.1 available)
  archive 4.0.7 (4.0.9 available)
  async 2.13.0 (2.13.1 available)
  cli_util 0.4.2 (0.5.1 available)
  cloud_firestore 6.1.2 (6.4.1 available)
  cloud_firestore_platform_interface 7.0.6 (8.0.1 available)
  cloud_firestore_web 5.1.2 (5.4.1 available)
  cloud_functions 6.0.7 (6.3.1 available)
  cloud_functions_platform_interface 5.8.10 (6.0.1 available)
  cloud_functions_web 5.1.3 (5.1.7 available)
  code_assets 1.0.0 (1.2.0 available)
  connectivity_plus 6.1.5 (7.1.1 available)
  connectivity_plus_platform_interface 2.0.1 (2.1.0 available)
  dbus 0.7.11 (0.7.13 available)
  device_info_plus 11.5.0 (13.1.0 available)
  device_info_plus_platform_interface 7.0.3 (8.1.0 available)
  ffi 2.1.5 (2.2.0 available)
  firebase_app_check 0.4.1+4 (0.4.4+1 available)
  firebase_app_check_platform_interface 0.2.1+4 (0.4.0+1 available)
  firebase_app_check_web 0.2.2+2 (0.2.4+2 available)
  firebase_auth 6.1.4 (6.5.1 available)
  firebase_auth_platform_interface 8.1.6 (9.0.1 available)
  firebase_auth_web 6.1.2 (6.2.1 available)
  firebase_core 4.5.0 (4.9.0 available)
  firebase_core_platform_interface 6.0.2 (7.0.1 available)
  firebase_core_web 3.5.0 (3.7.0 available)
  firebase_database 12.1.3 (12.4.1 available)
  firebase_database_platform_interface 0.3.0+2 (0.4.0+1 available)
  firebase_database_web 0.2.7+3 (0.2.7+8 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_local_notifications 17.2.4 (21.0.0 available)
  flutter_local_notifications_linux 4.0.1 (8.0.0 available)
  flutter_local_notifications_platform_interface 7.2.0 (11.0.0 available)
  flutter_timezone 3.0.1 (5.1.0 available)
  font_awesome_flutter 10.12.0 (11.0.0 available)
  google_fonts 6.3.3 (8.1.0 available)
  google_sign_in 6.3.0 (7.2.0 available)
  google_sign_in_android 6.2.1 (7.2.11 available)
  google_sign_in_ios 5.9.0 (6.3.0 available)
  google_sign_in_platform_interface 2.5.0 (3.1.0 available)
  google_sign_in_web 0.12.4+4 (1.1.3 available)
  gtk 2.1.0 (2.2.0 available)
  hooks 1.0.2 (2.0.0 available)
  image 4.7.2 (4.9.0 available)
  in_app_purchase_android 0.4.0+8 (0.5.0 available)
  in_app_purchase_storekit 0.4.7 (0.4.9 available)
  json_annotation 4.9.0 (4.12.0 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.17.0 (1.18.2 available)
  native_toolchain_c 0.17.6 (0.19.1 available)
  objective_c 9.3.0 (9.4.1 available)
  package_info_plus 8.3.1 (10.1.0 available)
  package_info_plus_platform_interface 3.2.1 (4.1.0 available)
  petitparser 7.0.1 (7.0.2 available)
  posix 6.0.3 (6.5.0 available)
  share_plus 10.1.4 (13.1.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  shared_preferences 2.5.4 (2.5.5 available)
  shared_preferences_android 2.4.18 (2.4.23 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  source_span 1.10.1 (1.10.2 available)
  sqflite 2.4.2 (2.4.2+1 available)
  sqflite_common 2.5.6 (2.5.8 available)
  synchronized 3.4.0 (3.4.0+1 available)
  test_api 0.7.10 (0.7.12 available)
  timezone 0.9.4 (0.11.0 available)
  url_launcher_android 6.3.28 (6.3.30 available)
  url_launcher_ios 6.3.6 (6.4.1 available)
  url_launcher_web 2.4.1 (2.4.3 available)
  vector_math 2.2.0 (2.3.0 available)
  vm_service 15.0.2 (15.2.0 available)
  win32 5.15.0 (6.3.0 available)
  win32_registry 2.1.0 (3.0.3 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
77 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.66 (1.3.71 available)
  app_links 6.4.1 (7.1.1 available)
  archive 4.0.7 (4.0.9 available)
  async 2.13.0 (2.13.1 available)
  cli_util 0.4.2 (0.5.1 available)
  cloud_firestore 6.1.2 (6.4.1 available)
  cloud_firestore_platform_interface 7.0.6 (8.0.1 available)
  cloud_firestore_web 5.1.2 (5.4.1 available)
  cloud_functions 6.0.7 (6.3.1 available)
  cloud_functions_platform_interface 5.8.10 (6.0.1 available)
  cloud_functions_web 5.1.3 (5.1.7 available)
  code_assets 1.0.0 (1.2.0 available)
  connectivity_plus 6.1.5 (7.1.1 available)
  connectivity_plus_platform_interface 2.0.1 (2.1.0 available)
  dbus 0.7.11 (0.7.13 available)
  device_info_plus 11.5.0 (13.1.0 available)
  device_info_plus_platform_interface 7.0.3 (8.1.0 available)
  ffi 2.1.5 (2.2.0 available)
  firebase_app_check 0.4.1+4 (0.4.4+1 available)
  firebase_app_check_platform_interface 0.2.1+4 (0.4.0+1 available)
  firebase_app_check_web 0.2.2+2 (0.2.4+2 available)
  firebase_auth 6.1.4 (6.5.1 available)
  firebase_auth_platform_interface 8.1.6 (9.0.1 available)
  firebase_auth_web 6.1.2 (6.2.1 available)
  firebase_core 4.5.0 (4.9.0 available)
  firebase_core_platform_interface 6.0.2 (7.0.1 available)
  firebase_core_web 3.5.0 (3.7.0 available)
  firebase_database 12.1.3 (12.4.1 available)
  firebase_database_platform_interface 0.3.0+2 (0.4.0+1 available)
  firebase_database_web 0.2.7+3 (0.2.7+8 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_local_notifications 17.2.4 (21.0.0 available)
  flutter_local_notifications_linux 4.0.1 (8.0.0 available)
  flutter_local_notifications_platform_interface 7.2.0 (11.0.0 available)
  flutter_timezone 3.0.1 (5.1.0 available)
  font_awesome_flutter 10.12.0 (11.0.0 available)
  google_fonts 6.3.3 (8.1.0 available)
  google_sign_in 6.3.0 (7.2.0 available)
  google_sign_in_android 6.2.1 (7.2.11 available)
  google_sign_in_ios 5.9.0 (6.3.0 available)
  google_sign_in_platform_interface 2.5.0 (3.1.0 available)
  google_sign_in_web 0.12.4+4 (1.1.3 available)
  gtk 2.1.0 (2.2.0 available)
  hooks 1.0.2 (2.0.0 available)
  image 4.7.2 (4.9.0 available)
  in_app_purchase_android 0.4.0+8 (0.5.0 available)
  in_app_purchase_storekit 0.4.7 (0.4.9 available)
  json_annotation 4.9.0 (4.12.0 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.17.0 (1.18.2 available)
  native_toolchain_c 0.17.6 (0.19.1 available)
  objective_c 9.3.0 (9.4.1 available)
  package_info_plus 8.3.1 (10.1.0 available)
  package_info_plus_platform_interface 3.2.1 (4.1.0 available)
  petitparser 7.0.1 (7.0.2 available)
  posix 6.0.3 (6.5.0 available)
  share_plus 10.1.4 (13.1.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  shared_preferences 2.5.4 (2.5.5 available)
  shared_preferences_android 2.4.18 (2.4.23 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  source_span 1.10.1 (1.10.2 available)
  sqflite 2.4.2 (2.4.2+1 available)
  sqflite_common 2.5.6 (2.5.8 available)
  synchronized 3.4.0 (3.4.0+1 available)
  test_api 0.7.10 (0.7.12 available)
  timezone 0.9.4 (0.11.0 available)
  url_launcher_android 6.3.28 (6.3.30 available)
  url_launcher_ios 6.3.6 (6.4.1 available)
  url_launcher_web 2.4.1 (2.4.3 available)
  vector_math 2.2.0 (2.3.0 available)
  vm_service 15.0.2 (15.2.0 available)
  win32 5.15.0 (6.3.0 available)
  win32_registry 2.1.0 (3.0.3 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
77 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib\main.dart on SM M315F in debug mode...
Note: Some input files use or override a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
Running Gradle task 'assembleDebug'...                            169.0s
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...          93.9s
Error: ADB exited with exit code 1
Performing Streamed Install

adb.exe: failed to install E:\work\xo-main\build\app\outputs\flutter-apk\app-debug.apk: Failure
[INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package com.xoarena.neonclash signatures do not match previously installed version;
ignoring!]
Uninstalling old version...
Installing build\app\outputs\flutter-apk\app-debug.apk...          66.8s
D/FlutterJNI( 1068): Beginning load of flutter...
D/FlutterJNI( 1068): flutter (null) was loaded normally!
I/flutter ( 1068): [IMPORTANT:flutter/shell/platform/android/android_context_gl_impeller.cc(104)] Using the Impeller rendering backend (OpenGLES).
D/FlutterRenderer( 1068): Width is zero. 0,0
I/flutter ( 1068): [FONT] runtime Google Fonts fetching disabled
I/flutter ( 1068): [FONT] using bundled Inter + Orbitron families
D/FlutterRenderer( 1068): Width is zero. 0,0
D/FlutterJNI( 1068): Sending viewport metrics to the engine.
I/SurfaceView@ddf1aa7( 1068): surfaceChanged (1080,2301) 1 #8 io.flutter.embedding.android.FlutterSurfaceView{ddf1aa7 V.E...... ......ID 0,0-1080,2301}
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] dp(2) 1 android.view.SurfaceView.updateSurface:1375 android.view.SurfaceView.lambda$new$1$SurfaceView:254 android.view.SurfaceView$$ExternalSyntheticLambda2.onPreDraw:2
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/Choreographer( 1068): Skipped 151 frames!  The application may be doing too much work on its main thread.
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
D/FlutterJNI( 1068): Sending viewport metrics to the engine.
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
I/flutter ( 1068): [main] App Check skipped (kEnableAppCheck=false). Enable in Firebase Console first.
I/Gralloc4( 1068): mapper 4.x is not supported
W/Gralloc3( 1068): mapper 3.x is not supported
I/gralloc ( 1068): Arm Module v1.0
I/Choreographer( 1068): Skipped 176 frames!  The application may be doing too much work on its main thread.
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] cancelDraw null isViewVisible: true
W/Gralloc4( 1068): allocator 4.x is not supported
W/Gralloc3( 1068): allocator 3.x is not supported
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] pdf(1) 1 android.view.SurfaceView.notifyDrawFinished:599 android.view.SurfaceView.performDrawFinished:586 android.view.SurfaceView.$r8$lambda$st27mCkd9jfJkTrN_P3qIGKX6NY:0
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): pendingDrawFinished. Waiting on draw reported mDrawsNeededToReport=1
D/ProfileInstaller( 1068): Installing profile for com.xoarena.neonclash
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): Creating frameDrawingCallback nextDrawUseBlastSync=false reportNextDraw=true hasBlurUpdates=false
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): Creating frameCompleteCallback
I/SurfaceView@ddf1aa7( 1068): uSP: rtp = Rect(0, 0 - 1080, 2301) rtsw = 1080 rtsh = 2301
I/SurfaceView@ddf1aa7( 1068): onSSPAndSRT: pl = 0 pt = 0 sx = 1.0 sy = 1.0
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): Received frameDrawingCallback frameNum=1. Creating transactionCompleteCallback=false
I/SurfaceView@ddf1aa7( 1068): aOrMT: uB = true t = android.view.SurfaceControl$Transaction@de5125a fN = 1 android.view.SurfaceView.access$500:124 android.view.SurfaceView$SurfaceViewPositionUpdateListener.positionChanged:1728 android.graphics.RenderNode$CompositePositionUpdateListener.positionChanged:319
I/SurfaceView@ddf1aa7( 1068): aOrMT: vR.mWNT, vR = ViewRootImpl@fabbf4a[MainActivity]
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): mWNT: t = android.view.SurfaceControl$Transaction@de5125a fN = 1 android.view.SurfaceView.applyOrMergeTransaction:1628 android.view.SurfaceView.access$500:124 android.view.SurfaceView$SurfaceViewPositionUpdateListener.positionChanged:1728
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): mWNT: merge t to BBQ
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): Received frameCompleteCallback  lastAcquiredFrameNum=1 lastAttemptedDrawFrameNum=1
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] pdf(0) 1 android.view.ViewRootImpl.lambda$addFrameCompleteCallbackIfNeeded$3$ViewRootImpl:5000 android.view.ViewRootImpl$$ExternalSyntheticLambda16.run:6 android.os.Handler.handleCallback:938
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): [DP] rdf()
D/ViewRootImpl@fabbf4a[MainActivity]( 1068): reportDrawFinished (fn: -1)
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): MSG_WINDOW_FOCUS_CHANGED 1 1
D/InputMethodManager( 1068): startInputInner - Id : 0
I/InputMethodManager( 1068): startInputInner - mService.startInputOrWindowGainedFocus
D/InputMethodManager( 1068): startInputInner - Id : 0
D/FlutterJNI( 1068): Sending viewport metrics to the engine.
I/flutter ( 1068): [PERF] delayed SoundService init — lazy on first use
Syncing files to device SM M315F...                                 4.5s

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on SM M315F is available at: http://127.0.0.1:62700/su4GxzdD8Do=/
The Flutter DevTools debugger and profiler on SM M315F is available at:
http://127.0.0.1:62700/su4GxzdD8Do=/devtools/?uri=ws://127.0.0.1:62700/su4GxzdD8Do=/ws
I/arena.neonclas( 1068): Thread[2,tid=1072,WaitingInMainSignalCatcherLoop,Thread*=0x7bd140e000,peer=0x2a402c0,"Signal Catcher"]: reacting to signal 10
I/arena.neonclas( 1068):
I/arena.neonclas( 1068): SIGUSR1 forcing GC (no HPROF) and profile save
I/arena.neonclas( 1068): Explicit concurrent copying GC freed 57KB AllocSpace bytes, 0(0B) LOS objects, 64% free, 3453KB/9597KB, paused 319us,59us total 71.023ms
W/arena.neonclas( 1068): Failed to flush directory /data/misc/profiles/cur/0/com.xoarena.neonclash: Permission denied
D/[secipm]( 1068): mSecIpmManager setProfileLength com.xoarena.neonclash profile:7226
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [AUTH] STEP 1: GoogleSignIn().signIn()
I/DecorView( 1068): [INFO] isPopOver=false, config=true
I/DecorView( 1068): updateCaptionType >> DecorView@537ee90[], isFloating=false, isApplication=true, hasWindowControllerCallback=true, hasWindowDecorCaption=false
D/DecorView( 1068): setCaptionType = 0, this = DecorView@537ee90[]
I/DecorView( 1068): getCurrentDensityDpi: from real metrics. densityDpi=420 msg=resources_loaded
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: ignored. pkg=com.xoarena.neonclash parent=null callers=com.android.internal.policy.DecorView.setVisibility:4295 android.app.ActivityThread.handleResumeActivity:5383 android.app.servertransaction.ResumeActivityItem.execute:54 android.app.servertransaction.ActivityTransactionItem.execute:45 android.app.servertransaction.TransactionExecutor.executeLifecycleState:176
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@537ee90[]
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): setView = com.android.internal.policy.DecorView@537ee90 TM=true
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@537ee90[SignInHubActivity]
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@537ee90[SignInHubActivity]
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): Relayout returned: old=(0,0,1080,2340) new=(0,0,1080,2340) req=(1080,2340)0 dur=19 res=0x7 s={true 531724214272} ch=true fn=-1
D/OpenGLRenderer( 1068): eglCreateWindowSurface
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): [DP] dp(1) 1 android.view.ViewRootImpl.reportNextDraw:11442 android.view.ViewRootImpl.performTraversals:4198 android.view.ViewRootImpl.doTraversal:2924
D/ViewRootImpl@d220266[SignInHubActivity]( 1068): Creating frameDrawingCallback nextDrawUseBlastSync=false reportNextDraw=true hasBlurUpdates=false
D/ViewRootImpl@d220266[SignInHubActivity]( 1068): Creating frameCompleteCallback
D/ViewRootImpl@d220266[SignInHubActivity]( 1068): Received frameDrawingCallback frameNum=1. Creating transactionCompleteCallback=false
D/ViewRootImpl@d220266[SignInHubActivity]( 1068): Received frameCompleteCallback  lastAcquiredFrameNum=1 lastAttemptedDrawFrameNum=1
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): [DP] pdf(0) 1 android.view.ViewRootImpl.lambda$addFrameCompleteCallbackIfNeeded$3$ViewRootImpl:5000 android.view.ViewRootImpl$$ExternalSyntheticLambda16.run:6 android.os.Handler.handleCallback:938
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): [DP] rdf()
D/ViewRootImpl@d220266[SignInHubActivity]( 1068): reportDrawFinished (fn: -1)
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): MSG_WINDOW_FOCUS_CHANGED 0 1
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
D/InputTransport( 1068): Input channel destroyed: 'ClientS', fd=122
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): stopped(false) old=false
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@537ee90[SignInHubActivity]
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@537ee90[SignInHubActivity]
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.google.android.gms.auth.api.signin.internal.SignInHubActivity
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): MSG_WINDOW_FOCUS_CHANGED 1 1
D/InputMethodManager( 1068): startInputInner - Id : 0
I/InputMethodManager( 1068): startInputInner - mService.startInputOrWindowGainedFocus
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): stopped(false) old=false
I/DecorView( 1068): notifyKeepScreenOnChanged: keepScreenOn=false
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [AUTH] STEP 1 OK: GoogleSignIn().signIn()
I/flutter ( 1068): [AUTH] STEP 2: Obtaining Google authentication credentials
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_NAVIGATION_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
D/InsetsSourceConsumer( 1068): ensureControlAlpha: for ITYPE_STATUS_BAR on com.xoarena.neonclash/com.xoarena.neonclash.MainActivity
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): MSG_WINDOW_FOCUS_CHANGED 0 1
D/FlutterJNI( 1068): Sending viewport metrics to the engine.
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): Relayout returned: old=(0,0,1080,2340) new=(0,0,1080,2340) req=(1080,2340)0 dur=4 res=0x1 s={true 530242142208} ch=false fn=3
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): updateBoundsLayer: t = android.view.SurfaceControl$Transaction@c39a2d8 sc = Surface(name=Bounds for - com.xoarena.neonclash/com.xoarena.neonclash.MainActivity@0)/@0xf385631 frame = 3
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): mWNT: t = android.view.SurfaceControl$Transaction@c39a2d8 fN = 3 android.view.ViewRootImpl.prepareSurfaces:2783 android.view.ViewRootImpl.performTraversals:4029 android.view.ViewRootImpl.doTraversal:2924
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): mWNT: merge t to BBQ
I/ViewRootImpl@fabbf4a[MainActivity]( 1068): MSG_WINDOW_FOCUS_CHANGED 1 1
D/InputMethodManager( 1068): startInputInner - Id : 0
I/InputMethodManager( 1068): startInputInner - mService.startInputOrWindowGainedFocus
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): stopped(true) old=false
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@537ee90[SignInHubActivity]
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@537ee90[SignInHubActivity]
I/MSHandlerLifeCycle( 1068): removeMultiSplitHandler: no exist. decor=DecorView@537ee90[SignInHubActivity]
D/OpenGLRenderer( 1068): setSurface called with nullptr
D/OpenGLRenderer( 1068): setSurface() destroyed EGLSurface
D/OpenGLRenderer( 1068): destroyEglSurface
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): dispatchDetachedFromWindow
D/InputTransport( 1068): Input channel destroyed: '9b6f59b', fd=129
I/ViewRootImpl@d220266[SignInHubActivity]( 1068): handleAppVisibility mAppVisible=true visible=false
I/flutter ( 1068): [AUTH] STEP 2 OK: Google authentication credentials obtained
I/flutter ( 1068): [AUTH] STEP 3: signInWithCredential
W/System  ( 1068): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 1068): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
W/System  ( 1068): Ignoring header X-Firebase-Locale because its value was null.
W/LocalRequestInterceptor( 1068): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
D/FirebaseAuth( 1068): Notifying id token listeners about user ( TbdqWqYbpaORpWT97MZqO9JrjgV2 ).
D/FirebaseAuth( 1068): Notifying auth state listeners about user ( TbdqWqYbpaORpWT97MZqO9JrjgV2 ).
I/flutter ( 1068): [AUTH] STEP 3 OK: signInWithCredential
I/flutter ( 1068): [AUTH] Google photoUrl: https://lh3.googleusercontent.com/a/ACg8ocImsJA3sKMZZpZzQXhZSn1mZo4OebC6dLn_StXXcTzQDfSVow=s96-c, Firebase photoURL: https://lh3.googleusercontent.com/a/ACg8ocImsJA3sKMZZpZzQXhZSn1mZo4OebC6dLn_StXXcTzQDfSVow=s96-c
I/flutter ( 1068): [AUTH] STEP 4: Checking if profile exists in Firestore
D/ConnectivityManager( 1068): StackLog: [android.net.ConnectivityManager.sendRequestForNetwork(ConnectivityManager.java:4740)] [android.net.ConnectivityManager.registerDefaultNetworkCallbackForUid(ConnectivityManager.java:5465)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5432)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5406)] [com.google.firebase.firestore.remote.AndroidConnectivityMonitor.configureNetworkMonitoring(AndroidConnectivityMonitor.java:87)] [com.google.firebase.firestore.remote.AndroidConnectivityMonitor.<init>(AndroidConnectivityMonitor.java:64)] [com.google.firebase.firestore.remote.RemoteComponenetProvider.createConnectivityMonitor(RemoteComponenetProvider.java:94)] [com.google.firebase.firestore.remote.RemoteComponenetProvider.initialize(RemoteComponenetProvider.java:41)] [com.google.firebase.firestore.core.ComponentProvider.initialize(ComponentProvider.java:158)] [com.google.firebase.firestore.core.FirestoreClient.initialize(FirestoreClient.java:290)] [com.google.firebase.firestore.core.FirestoreClient.lambda$new$0$com-google-firebase-firestore-core-FirestoreClient(FirestoreClient.java:111)] [com.google.firebase.firestore.core.FirestoreClient$$ExternalSyntheticLambda12.run(D8$$SyntheticClass:0)] [com.google.firebase.firestore.util.AsyncQueue.lambda$enqueue$2(AsyncQueue.java:445)] [com.google.firebase.firestore.util.AsyncQueue$$ExternalSyntheticLambda4.call(D8$$SyntheticClass:0)] [com.google.firebase.firestore.util.AsyncQueue$SynchronizedShutdownAwareExecutor.lambda$executeAndReportResult$1(AsyncQueue.java:330)] [com.google.firebase.firestore.util.AsyncQueue$SynchronizedShutdownAwareExecutor$$ExternalSyntheticLambda2.run(D8$$SyntheticClass:0)] [java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:520)] [java.util.concurrent.FutureTask.run(FutureTask.java:317)] [java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:348)] [java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1154)] [java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:652)] [com.google.firebase.firestore.util.AsyncQueue$SynchronizedShutdownAwareExecutor$DelayedStartFactory.run(AsyncQueue.java:235)] [java.lang.Thread.run(Thread.java:1564)]
W/DynamiteModule( 1068): Local module descriptor class for com.google.android.gms.providerinstaller.dynamite not found.
I/DynamiteModule( 1068): Considering local module com.google.android.gms.providerinstaller.dynamite:0 and remote module com.google.android.gms.providerinstaller.dynamite:0
W/ProviderInstaller( 1068): Failed to load providerinstaller module: No acceptable module com.google.android.gms.providerinstaller.dynamite found. Local version is 0 and remote version is 0.
D/nativeloader( 1068): Configuring clns-5 for other apk /system/framework/org.apache.http.legacy.jar. target_sdk_version=37, uses_libraries=ALL, library_path=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/lib/arm64:/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
D/nativeloader( 1068): Extending system_exposed_libraries: libteecl.teegris.samsung.so:libperfsdk.performance.samsung.so:libSEF.quram.so:libimagecodec.quram.so:libagifencoder.quram.so:libss_jni.securestorage.samsung.so:libneural.snap.samsung.so:libsnap_hidl.snap.samsung.so:libsce_v1.crypto.samsung.so:libSecEmbms.telephony.samsung.so:libSFEffect.fonteffect.samsung.so:libBestComposition.polarr.so:libTracking.polarr.so:libFeature.polarr.so:libPolarrSnap.polarr.so:libYuv.polarr.so:lib.engmodejni.samsung.so:libknox_remotedesktopclient.knox.samsung.so:libBeauty_v4.camera.samsung.so:libexifa.camera.samsung.so:libjpega.camera.samsung.so:libOpenCv.camera.samsung.so:libImageScreener.camera.samsung.so:libMyFilter.camera.samsung.so:libtensorflowLite.myfilter.camera.samsung.so:libtensorflowlite_inference_api.myfilter.camera.samsung.so:libEventFinder.camera.samsung.so:libHIDTSnapJNI.camera.samsung.so:libSmartScan.camera.samsung.so:libRectify.camera.samsung.so:libDocRectifyWrapper.camera.samsung.so:libUltraWideDistortionCorrection.camera.samsung
D/nativeloader( 1068): Configuring clns-6 for other apk /apex/com.android.extservices/javalib/android.ext.adservices.jar. target_sdk_version=37, uses_libraries=ALL, library_path=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/lib/arm64:/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
D/nativeloader( 1068): Extending system_exposed_libraries: libteecl.teegris.samsung.so:libperfsdk.performance.samsung.so:libSEF.quram.so:libimagecodec.quram.so:libagifencoder.quram.so:libss_jni.securestorage.samsung.so:libneural.snap.samsung.so:libsnap_hidl.snap.samsung.so:libsce_v1.crypto.samsung.so:libSecEmbms.telephony.samsung.so:libSFEffect.fonteffect.samsung.so:libBestComposition.polarr.so:libTracking.polarr.so:libFeature.polarr.so:libPolarrSnap.polarr.so:libYuv.polarr.so:lib.engmodejni.samsung.so:libknox_remotedesktopclient.knox.samsung.so:libBeauty_v4.camera.samsung.so:libexifa.camera.samsung.so:libjpega.camera.samsung.so:libOpenCv.camera.samsung.so:libImageScreener.camera.samsung.so:libMyFilter.camera.samsung.so:libtensorflowLite.myfilter.camera.samsung.so:libtensorflowlite_inference_api.myfilter.camera.samsung.so:libEventFinder.camera.samsung.so:libHIDTSnapJNI.camera.samsung.so:libSmartScan.camera.samsung.so:libRectify.camera.samsung.so:libDocRectifyWrapper.camera.samsung.so:libUltraWideDistortionCorrection.camera.samsung
D/nativeloader( 1068): InitApexLibraries:
D/nativeloader( 1068):   com_android_appsearch: libicing.so
D/nativeloader( 1068):   com_android_art: libartservice.so
D/nativeloader( 1068):   com_android_conscrypt: libjavacrypto.so
D/nativeloader( 1068):   com_android_extservices: libtflite_support_classifiers_native.so
D/nativeloader( 1068):   com_android_mediaprovider: libpdfclient.so
D/nativeloader( 1068):   com_android_os_statsd: libstats_jni.so
D/nativeloader( 1068):   com_android_tethering: libandroid_net_connectivity_com_android_net_module_util_jni.so:libandroid_net_connectivity_com_android_net_module_util_jni_CommonConnectivityJni.so:libframework-connectivity-jni.so:libframework-connectivity-tiramisu-jni.so:libmainlinecronet.144.0.7500.8.so:libservice-connectivity.so:libservice-thread-jni.so:stable_cronet_libcrypto.so
W/arena.neonclas( 1068): Loading /data/misc/apexdata/com.android.art/dalvik-cache/arm64/system@framework@com.android.location.provider.jar@classes.odex non-executable as it requires an image which we failed to load
D/nativeloader( 1068): Configuring clns-7 for other apk /system/framework/com.android.location.provider.jar. target_sdk_version=37, uses_libraries=ALL, library_path=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/lib/arm64:/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
D/nativeloader( 1068): Extending system_exposed_libraries: libteecl.teegris.samsung.so:libperfsdk.performance.samsung.so:libSEF.quram.so:libimagecodec.quram.so:libagifencoder.quram.so:libss_jni.securestorage.samsung.so:libneural.snap.samsung.so:libsnap_hidl.snap.samsung.so:libsce_v1.crypto.samsung.so:libSecEmbms.telephony.samsung.so:libSFEffect.fonteffect.samsung.so:libBestComposition.polarr.so:libTracking.polarr.so:libFeature.polarr.so:libPolarrSnap.polarr.so:libYuv.polarr.so:lib.engmodejni.samsung.so:libknox_remotedesktopclient.knox.samsung.so:libBeauty_v4.camera.samsung.so:libexifa.camera.samsung.so:libjpega.camera.samsung.so:libOpenCv.camera.samsung.so:libImageScreener.camera.samsung.so:libMyFilter.camera.samsung.so:libtensorflowLite.myfilter.camera.samsung.so:libtensorflowlite_inference_api.myfilter.camera.samsung.so:libEventFinder.camera.samsung.so:libHIDTSnapJNI.camera.samsung.so:libSmartScan.camera.samsung.so:libRectify.camera.samsung.so:libDocRectifyWrapper.camera.samsung.so:libUltraWideDistortionCorrection.camera.samsung
D/nativeloader( 1068): Configuring clns-8 for other apk /system/framework/com.android.media.remotedisplay.jar. target_sdk_version=37, uses_libraries=ALL, library_path=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/lib/arm64:/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
D/nativeloader( 1068): Extending system_exposed_libraries: libteecl.teegris.samsung.so:libperfsdk.performance.samsung.so:libSEF.quram.so:libimagecodec.quram.so:libagifencoder.quram.so:libss_jni.securestorage.samsung.so:libneural.snap.samsung.so:libsnap_hidl.snap.samsung.so:libsce_v1.crypto.samsung.so:libSecEmbms.telephony.samsung.so:libSFEffect.fonteffect.samsung.so:libBestComposition.polarr.so:libTracking.polarr.so:libFeature.polarr.so:libPolarrSnap.polarr.so:libYuv.polarr.so:lib.engmodejni.samsung.so:libknox_remotedesktopclient.knox.samsung.so:libBeauty_v4.camera.samsung.so:libexifa.camera.samsung.so:libjpega.camera.samsung.so:libOpenCv.camera.samsung.so:libImageScreener.camera.samsung.so:libMyFilter.camera.samsung.so:libtensorflowLite.myfilter.camera.samsung.so:libtensorflowlite_inference_api.myfilter.camera.samsung.so:libEventFinder.camera.samsung.so:libHIDTSnapJNI.camera.samsung.so:libSmartScan.camera.samsung.so:libRectify.camera.samsung.so:libDocRectifyWrapper.camera.samsung.so:libUltraWideDistortionCorrection.camera.samsung
D/nativeloader( 1068): Configuring clns-9 for other apk /data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk. target_sdk_version=37, uses_libraries=, library_path=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/lib/arm64:/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a, permitted_path=/data:/mnt/expand:/data/user/0/com.google.android.gms
I/arena.neonclas( 1068): hiddenapi: Accessing hidden method Ldalvik/system/VMStack;->getStackClass2()Ljava/lang/Class; (runtime_flags=0, domain=core-platform, api=unsupported) from Lheet; (domain=app, TargetSdkVersion=35) using reflection: allowed
E/GoogleApiManager( 1068): Failed to get service from broker.
E/GoogleApiManager( 1068): java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
E/GoogleApiManager( 1068):      at android.os.Parcel.createExceptionOrNull(Parcel.java:2438)
E/GoogleApiManager( 1068):      at android.os.Parcel.createException(Parcel.java:2422)
E/GoogleApiManager( 1068):      at android.os.Parcel.readException(Parcel.java:2405)
E/GoogleApiManager( 1068):      at android.os.Parcel.readException(Parcel.java:2347)
E/GoogleApiManager( 1068):      at bioy.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):36)
E/GoogleApiManager( 1068):      at bimu.z(:com.google.android.gms@261833029@26.18.33 (190400-913931251):143)
E/GoogleApiManager( 1068):      at bhso.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):42)
E/GoogleApiManager( 1068):      at android.os.Handler.handleCallback(Handler.java:938)
E/GoogleApiManager( 1068):      at android.os.Handler.dispatchMessage(Handler.java:99)
E/GoogleApiManager( 1068):      at cyek.mP(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
E/GoogleApiManager( 1068):      at cyek.dispatchMessage(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
E/GoogleApiManager( 1068):      at android.os.Looper.loopOnce(Looper.java:226)
E/GoogleApiManager( 1068):      at android.os.Looper.loop(Looper.java:313)
E/GoogleApiManager( 1068):      at android.os.HandlerThread.run(HandlerThread.java:67)
W/GoogleApiManager( 1068): Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 1068): Failed to register com.google.android.gms.providerinstaller#com.xoarena.neonclash
W/FlagRegistrar( 1068): gjvm: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 1068):         at gjvo.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):13)
W/FlagRegistrar( 1068):         at hjtd.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):3)
W/FlagRegistrar( 1068):         at hjtf.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):139)
W/FlagRegistrar( 1068):         at hjvn.execute(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagRegistrar( 1068):         at hjtn.f(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagRegistrar( 1068):         at hjtn.m(:com.google.android.gms@261833029@26.18.33 (190400-913931251):101)
W/FlagRegistrar( 1068):         at hjtn.q(:com.google.android.gms@261833029@26.18.33 (190400-913931251):16)
W/FlagRegistrar( 1068):         at gbjq.hH(:com.google.android.gms@261833029@26.18.33 (190400-913931251):35)
W/FlagRegistrar( 1068):         at fnvi.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):12)
W/FlagRegistrar( 1068):         at hjvn.execute(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagRegistrar( 1068):         at fnvj.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):18)
W/FlagRegistrar( 1068):         at fnvy.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):34)
W/FlagRegistrar( 1068):         at fnwa.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):22)
W/FlagRegistrar( 1068):         at bhpv.e(:com.google.android.gms@261833029@26.18.33 (190400-913931251):9)
W/FlagRegistrar( 1068):         at bhsm.q(:com.google.android.gms@261833029@26.18.33 (190400-913931251):48)
W/FlagRegistrar( 1068):         at bhsm.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):10)
W/FlagRegistrar( 1068):         at bhsm.g(:com.google.android.gms@261833029@26.18.33 (190400-913931251):191)
W/FlagRegistrar( 1068):         at bhsm.onConnectionFailed(:com.google.android.gms@261833029@26.18.33 (190400-913931251):2)
W/FlagRegistrar( 1068):         at bhso.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):70)
W/FlagRegistrar( 1068):         at android.os.Handler.handleCallback(Handler.java:938)
W/FlagRegistrar( 1068):         at android.os.Handler.dispatchMessage(Handler.java:99)
W/FlagRegistrar( 1068):         at cyek.mP(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagRegistrar( 1068):         at cyek.dispatchMessage(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
W/FlagRegistrar( 1068):         at android.os.Looper.loopOnce(Looper.java:226)
W/FlagRegistrar( 1068):         at android.os.Looper.loop(Looper.java:313)
W/FlagRegistrar( 1068):         at android.os.HandlerThread.run(HandlerThread.java:67)
W/FlagRegistrar( 1068): Caused by: bhoa: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagRegistrar( 1068):         at bimg.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):15)
W/FlagRegistrar( 1068):         at bhpy.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagRegistrar( 1068):         at bhpv.e(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
W/FlagRegistrar( 1068):         ... 12 more
D/nativeloader( 1068): Load /data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk!/lib/arm64-v8a/libconscrypt_gmscore_jni.so using class loader ns clns-9 (caller=/data/app/~~sPTCMhDN4ao6hbdCi_F4Zg==/com.google.android.gms-tHHg8E9dmNBbC5e3PyQMCA==/base.apk): ok
V/NativeCrypto( 1068): Registering com/google/android/gms/org/conscrypt/NativeCrypto's 336 native methods...
W/FlagStore( 1068): Unable to update local snapshot for com.google.android.gms.providerinstaller#com.xoarena.neonclash, may result in stale flags.
W/FlagStore( 1068): java.util.concurrent.ExecutionException: gjvm: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 1068):     at hjtn.j(:com.google.android.gms@261833029@26.18.33 (190400-913931251):21)
W/FlagStore( 1068):     at hjtw.t(:com.google.android.gms@261833029@26.18.33 (190400-913931251):24)
W/FlagStore( 1068):     at hjtn.get(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at hjyb.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):2)
W/FlagStore( 1068):     at hjwr.s(:com.google.android.gms@261833029@26.18.33 (190400-913931251):10)
W/FlagStore( 1068):     at gkba.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at gkae.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
W/FlagStore( 1068):     at java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:520)
W/FlagStore( 1068):     at java.util.concurrent.FutureTask.run(FutureTask.java:317)
W/FlagStore( 1068):     at java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:348)
W/FlagStore( 1068):     at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1154)
W/FlagStore( 1068):     at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:652)
W/FlagStore( 1068):     at java.lang.Thread.run(Thread.java:1564)
W/FlagStore( 1068): Caused by: gjvm: 17: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 1068):     at gjvo.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):13)
W/FlagStore( 1068):     at hjtd.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):3)
W/FlagStore( 1068):     at hjtf.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):139)
W/FlagStore( 1068):     at hjvn.execute(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at hjtn.f(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at hjtn.m(:com.google.android.gms@261833029@26.18.33 (190400-913931251):101)
W/FlagStore( 1068):     at hjtn.q(:com.google.android.gms@261833029@26.18.33 (190400-913931251):16)
W/FlagStore( 1068):     at gbjq.hH(:com.google.android.gms@261833029@26.18.33 (190400-913931251):35)
W/FlagStore( 1068):     at fnvi.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):12)
W/FlagStore( 1068):     at hjvn.execute(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at fnvj.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):18)
W/FlagStore( 1068):     at fnvy.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):34)
W/FlagStore( 1068):     at fnwf.B(:com.google.android.gms@261833029@26.18.33 (190400-913931251):17)
W/FlagStore( 1068):     at fnva.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):60)
W/FlagStore( 1068):     at hjvn.execute(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at fnvb.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):8)
W/FlagStore( 1068):     at fnvy.b(:com.google.android.gms@261833029@26.18.33 (190400-913931251):34)
W/FlagStore( 1068):     at fnwa.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):22)
W/FlagStore( 1068):     at bhpv.e(:com.google.android.gms@261833029@26.18.33 (190400-913931251):9)
W/FlagStore( 1068):     at bhsm.q(:com.google.android.gms@261833029@26.18.33 (190400-913931251):48)
W/FlagStore( 1068):     at bhsm.d(:com.google.android.gms@261833029@26.18.33 (190400-913931251):10)
W/FlagStore( 1068):     at bhsm.g(:com.google.android.gms@261833029@26.18.33 (190400-913931251):191)
W/FlagStore( 1068):     at bhsm.onConnectionFailed(:com.google.android.gms@261833029@26.18.33 (190400-913931251):2)
W/FlagStore( 1068):     at bhso.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):70)
W/FlagStore( 1068):     at android.os.Handler.handleCallback(Handler.java:938)
W/FlagStore( 1068):     at android.os.Handler.dispatchMessage(Handler.java:99)
W/FlagStore( 1068):     at cyek.mP(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at cyek.dispatchMessage(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
W/FlagStore( 1068):     at android.os.Looper.loopOnce(Looper.java:226)
W/FlagStore( 1068):     at android.os.Looper.loop(Looper.java:313)
W/FlagStore( 1068):     at android.os.HandlerThread.run(HandlerThread.java:67)
W/FlagStore( 1068): Caused by: bhoa: 17: API: Phenotype.API is not available on this device. Connection failed with: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
W/FlagStore( 1068):     at bimg.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):15)
W/FlagStore( 1068):     at bhpy.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
W/FlagStore( 1068):     at bhpv.e(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
W/FlagStore( 1068):     ... 12 more
W/arena.neonclas( 1068): Cleared Reference was only reachable from finalizer (only reported once)
I/arena.neonclas( 1068): hiddenapi: Accessing hidden method Ljava/security/spec/ECParameterSpec;->getCurveName()Ljava/lang/String; (runtime_flags=0, domain=core-platform, api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform; (domain=app, TargetSdkVersion=35) using reflection: allowed
I/arena.neonclas( 1068): Background concurrent copying GC freed 3372KB AllocSpace bytes, 20(880KB) LOS objects, 49% free, 6968KB/13MB, paused 364us,126us total 158.881ms
D/OpenGLRenderer( 1068): setSurface called with nullptr
D/InputTransport( 1068): Input channel destroyed: 'ClientS', fd=165
I/ProviderInstaller( 1068): Installed default security provider GmsCore_OpenSSL
D/ConnectivityManager( 1068): StackLog: [android.net.ConnectivityManager.sendRequestForNetwork(ConnectivityManager.java:4740)] [android.net.ConnectivityManager.registerDefaultNetworkCallbackForUid(ConnectivityManager.java:5465)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5432)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5406)] [io.grpc.android.AndroidChannelBuilder$AndroidChannel.configureNetworkMonitoring(AndroidChannelBuilder.java:217)] [io.grpc.android.AndroidChannelBuilder$AndroidChannel.<init>(AndroidChannelBuilder.java:198)] [io.grpc.android.AndroidChannelBuilder.build(AndroidChannelBuilder.java:169)] [com.google.firebase.firestore.remote.GrpcCallProvider.initChannel(GrpcCallProvider.java:116)] [com.google.firebase.firestore.remote.GrpcCallProvider.lambda$initChannelTask$6$com-google-firebase-firestore-remote-GrpcCallProvider(GrpcCallProvider.java:242)] [com.google.firebase.firestore.remote.GrpcCallProvider$$ExternalSyntheticLambda4.call(D8$$SyntheticClass:0)] [com.google.android.gms.tasks.zzx.run(com.google.android.gms:play-services-tasks@@18.4.0:1)] [com.google.firebase.firestore.util.ThrottledForwardingExecutor.lambda$execute$0$com-google-firebase-firestore-util-ThrottledForwardingExecutor(ThrottledForwardingExecutor.java:54)] [com.google.firebase.firestore.util.ThrottledForwardingExecutor$$ExternalSyntheticLambda0.run(D8$$SyntheticClass:0)] [java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1154)] [java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:652)] [java.lang.Thread.run(Thread.java:1564)]
I/arena.neonclas( 1068): hiddenapi: Accessing hidden field Ljava/net/Socket;->impl:Ljava/net/SocketImpl; (runtime_flags=0, domain=core-platform, api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform; (domain=app, TargetSdkVersion=35) using reflection: allowed
I/arena.neonclas( 1068): hiddenapi: Accessing hidden method Ljava/security/spec/ECParameterSpec;->setCurveName(Ljava/lang/String;)V (runtime_flags=0, domain=core-platform, api=unsupported) from Lcom/google/android/gms/org/conscrypt/Platform; (domain=app, TargetSdkVersion=35) using reflection: allowed
I/flutter ( 1068): [AUTH] STEP 5: saveUserToFirestore
I/flutter ( 1068): [AUTH] STEP 5 OK: saveUserToFirestore
I/flutter ( 1068): [AUTH] STEP 6: syncToLocalStore
I/flutter ( 1068): [AUTH] STEP 6 OK: syncToLocalStore
I/flutter ( 1068): [AUTH] STEP 7: userRepo.initAfterAuth
I/flutter ( 1068): [AUTH] UserRepo: initAfterAuth start
I/flutter ( 1068): [AUTH] UserRepo: pullServerToLocal start
I/flutter ( 1068): [AUTH] UserRepo: pullServerToLocal success uid=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [REFERRAL] ensureCode start uid=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [REFERRAL] code already=214997246
I/flutter ( 1068): [AUTH] STEP 7 OK: userRepo.initAfterAuth
I/flutter ( 1068): [AUTH] Login status saved to SharedPreferences
I/flutter ( 1068): [SESSION] Written session 1780108609853 for TbdqWqYbpaORpWT97MZqO9JrjgV2 on Samsung SM-M315F
I/flutter ( 1068): [PROFILE] no equipped avatar — showing profile image only
I/flutter ( 1068): [PROFILE] no equipped avatar — showing profile image only
I/flutter ( 1068): [MUSIC] init triggered from HomeHub
I/flutter ( 1068): [NOTIF] Timezone initialized: Africa/Cairo
D/ConnectivityManager( 1068): StackLog: [android.net.ConnectivityManager.sendRequestForNetwork(ConnectivityManager.java:4740)] [android.net.ConnectivityManager.registerDefaultNetworkCallbackForUid(ConnectivityManager.java:5465)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5432)] [android.net.ConnectivityManager.registerDefaultNetworkCallback(ConnectivityManager.java:5406)] [dev.fluttercommunity.plus.connectivity.ConnectivityBroadcastReceiver.onListen(ConnectivityBroadcastReceiver.java:77)] [io.flutter.plugin.common.EventChannel$IncomingStreamRequestHandler.onListen(EventChannel.java:218)] [io.flutter.plugin.common.EventChannel$IncomingStreamRequestHandler.onMessage(EventChannel.java:197)] [io.flutter.embedding.engine.dart.DartMessenger.invokeHandler(DartMessenger.java:286)] [io.flutter.embedding.engine.dart.DartMessenger.lambda$dispatchMessageToQueue$0$io-flutter-embedding-engine-dart-DartMessenger(DartMessenger.java:313)] [io.flutter.embedding.engine.dart.DartMessenger$$ExternalSyntheticLambda0.run(D8$$SyntheticClass:0)]
I/flutter ( 1068): [MUSIC] prefs loaded — musicEnabled=true musicVolume=0.7
I/flutter ( 1068): [NOTIF] channel created (daily_reminder, high importance, vibration)
I/flutter ( 1068): [NOTIF] init complete
I/flutter ( 1068): [NOTIF] permission result: granted=true
I/flutter ( 1068): [MUSIC] init complete — starting music: true
I/flutter ( 1068): [MUSIC] start requested — volume=0.7
I/flutter ( 1068): [IAP] starting after AppMode.online
I/flutter ( 1068): [IAP] Found 0 past purchases
I/flutter ( 1068): [IAP] Finished consuming pending purchases
V/MediaPlayer-JNI( 1068): native_setup
V/MediaPlayerNative( 1068): constructor
V/MediaPlayerNative( 1068): setListener
V/MediaPlayer-JNI( 1068): setParameter: key 1400
V/MediaPlayerNative( 1068): MediaPlayer::setParameter(1400)
V/MediaPlayer-JNI( 1068): reset
V/MediaPlayerNative( 1068): reset
V/MediaPlayer( 1068): resetDrmState:  mDrmInfo=null mDrmProvisioningThread=null mPrepareDrmInProgress=false mActiveDrmScheme=false
V/MediaPlayer( 1068): cleanDrmObj: mDrmObj=null mDrmSessionId=null
V/MediaPlayer-JNI( 1068): setDataSourceFD: fd 150
V/MediaPlayerNative( 1068): setDataSource(150, 0, 576460752303423487)
D/SharedPreferencesImpl( 1068): Time required to fsync /data/user/0/com.xoarena.neonclash/shared_prefs/notification_plugin_cache.xml: [<1: 0, <2: 0, <4: 0, <8: 0, <16: 0, <32: 0, <64: 0, <128: 0, <256: 0, <512: 0, <1024: 1, <2048: 0, <4096: 0, <8192: 0, <16384: 0, >=16384: 0]
V/MediaPlayer-JNI( 1068): setVolume: left 0.700000  right 0.700000
V/MediaPlayerNative( 1068): MediaPlayer::setVolume(0.700000, 0.700000)
V/MediaPlayer-JNI( 1068): setLooping: 1
V/MediaPlayerNative( 1068): MediaPlayer::setLooping
V/MediaPlayerNative( 1068): setVideoSurfaceTexture
V/MediaPlayerNative( 1068): prepareAsync
V/MediaPlayerNative( 1068): message received msg=200, ext1=10973, ext2=0
W/MediaPlayerNative( 1068): info/warning (10973, 0)
V/MediaPlayerNative( 1068): message received msg=1, ext1=0, ext2=0
V/MediaPlayerNative( 1068): MediaPlayer::notify() prepared
V/MediaPlayerNative( 1068): invoke 76
V/MediaPlayerNative( 1068): getDuration_l
V/MediaPlayer-JNI( 1068): getDuration: 29952 (msec)
I/flutter ( 1068): [NOTIF] permission result: granted=true
D/CompatibilityChangeReporter( 1068): Compat change id reported: 160794467; UID 10439; state: ENABLED
V/MediaPlayer-JNI( 1068): getPlaybackSettings: 1.000000 1.000000 2 0
V/MediaPlayer-JNI( 1068): setPlaybackParams: 1:1.000000 1:1.000000 1:2 1:0
V/MediaPlayerNative( 1068): setPlaybackSettings: 1.000000 1.000000 2 0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
I/flutter ( 1068): [AVATAR_ANALYSIS] lazy analyze asset=assets/avatar/Avatar__3.png
I/flutter ( 1068): [NOTIF] Scheduled daily at 2026-05-30 21:00:00.000+0300 — 1 pending request(s)
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/flutter ( 1068): [AVATAR_ANALYSIS] analyzed asset=assets/avatar/Avatar__3.png center=(0.498, 0.451) r=0.248
E/GoogleApiManager( 1068): Failed to get service from broker.
E/GoogleApiManager( 1068): java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
E/GoogleApiManager( 1068):      at android.os.Parcel.createExceptionOrNull(Parcel.java:2438)
E/GoogleApiManager( 1068):      at android.os.Parcel.createException(Parcel.java:2422)
E/GoogleApiManager( 1068):      at android.os.Parcel.readException(Parcel.java:2405)
E/GoogleApiManager( 1068):      at android.os.Parcel.readException(Parcel.java:2347)
E/GoogleApiManager( 1068):      at bioy.a(:com.google.android.gms@261833029@26.18.33 (190400-913931251):36)
E/GoogleApiManager( 1068):      at bimu.z(:com.google.android.gms@261833029@26.18.33 (190400-913931251):143)
E/GoogleApiManager( 1068):      at bhso.run(:com.google.android.gms@261833029@26.18.33 (190400-913931251):42)
E/GoogleApiManager( 1068):      at android.os.Handler.handleCallback(Handler.java:938)
E/GoogleApiManager( 1068):      at android.os.Handler.dispatchMessage(Handler.java:99)
E/GoogleApiManager( 1068):      at cyek.mP(:com.google.android.gms@261833029@26.18.33 (190400-913931251):1)
E/GoogleApiManager( 1068):      at cyek.dispatchMessage(:com.google.android.gms@261833029@26.18.33 (190400-913931251):5)
E/GoogleApiManager( 1068):      at android.os.Looper.loopOnce(Looper.java:226)
E/GoogleApiManager( 1068):      at android.os.Looper.loop(Looper.java:313)
E/GoogleApiManager( 1068):      at android.os.HandlerThread.run(HandlerThread.java:67)
W/GoogleApiManager( 1068): Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [REFERRAL] ensureCode start uid=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [REFERRAL] code already=214997246
I/TRuntime.CctTransportBackend( 1068): Making request to: https://firebaselogging.googleapis.com/v0cc/log/batch?format=json_proto3
I/TRuntime.CctTransportBackend( 1068): Status Code: 200
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] created room code=241061
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=rooms/241061
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/241061/_hostLeftAt failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/arena.neonclas( 1068): Background concurrent copying GC freed 4861KB AllocSpace bytes, 16(768KB) LOS objects, 49% free, 6839KB/13MB, paused 279us,107us total 106.256ms
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): updateChildren at /rooms/241061 failed: DatabaseError: Permission denied
I/flutter ( 1068): [ARENA_KICK] update failed: [firebase_database/unknown] Firebase Database error: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): updateChildren at /rooms/241061 failed: DatabaseError: Permission denied
I/flutter ( 1068): [ARENA_KICK] update failed: [firebase_database/unknown] Firebase Database error: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): updateChildren at /rooms/241061 failed: DatabaseError: Permission denied
I/flutter ( 1068): [ARENA_KICK] update failed: [firebase_database/unknown] Firebase Database error: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [AVATAR_ANALYSIS] using hardcoded override for assets/avatar/Avatar__10.gif
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=rooms/241061
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=.info/connected
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/flutter ( 1068): [ARENA] countdown started room=241061
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/241061/_hostLeftAt failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/flutter ( 1068): [WALLET] applying delta source=friend_room_bet_entry delta=-50 before=6279 after=6229
I/flutter ( 1068): [WALLET_LEDGER] created transactionId=arena_241061_1780108655971_TbdqWqYbpaORpWT97MZqO9JrjgV2_bet_TbdqWqYbpaORpWT97MZqO9JrjgV2 type=debit source=friend_room_bet_entry delta=-50
I/flutter ( 1068): [WALLET_LEDGER] Firestore ledger write success
I/flutter ( 1068): [ARENA_BET] debit success uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 amount=50
I/flutter ( 1068): [ARENA_BET] locked bet uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 amount=50 prizePool=100
I/flutter ( 1068): [ARENA_BET] both bets locked code=241061 prizePool=100
I/flutter ( 1068): [ARENA] game started room=241061
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=4 committed=true
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=2 committed=true
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA_WIN_CHECK] boardSize=3 requiredLineLength=3 winner=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [ARENA_ROUND] room=241061 resolvedKey=1:3:X|X|O|X|O||O|| result=host
I/flutter ( 1068): [ARENA_BET] payout check room=241061 self=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=6 committed=true
W/RepoOperation( 1068): updateChildren at /rooms/241061 failed: DatabaseError: Permission denied
I/flutter ( 1068): [main] Unhandled zone error: [firebase_database/unknown] Firebase Database error: Permission denied
I/flutter ( 1068): #0      FirebaseDatabaseHostApi.databaseReferenceUpdate (package:firebase_database_platform_interface/src/pigeon/messages.pigeon.dart:851:7)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #1      MethodChannelDatabaseReference.update (package:firebase_database_platform_interface/src/method_channel/method_channel_database_reference.dart:119:7)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #2      ArenaRepo.finishMatchAtomic (package:xo_arena_neon_clash/services/arena/arena_repo.dart:724:5)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #3      _ArenaGamePageState._resolveRound (package:xo_arena_neon_clash/screens/arena/arena_game_page.dart:643:7)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): [ARENA_BET] payout blocked: transaction not committed
I/flutter ( 1068): [ARENA] summary result matchId=arena_241061_1780108655971_TbdqWqYbpaORpWT97MZqO9JrjgV2 self=TbdqWqYbpaORpWT97MZqO9JrjgV2 savedSelf=true savedGlobal=true
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] exit room once room=241061
W/RepoOperation( 1068): setValue at /rooms/241061/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [REFERRAL] ensureCode start uid=TbdqWqYbpaORpWT97MZqO9JrjgV2
I/flutter ( 1068): [REFERRAL] code already=214997246
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] room deleted code=241061
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/arena.neonclas( 1068): Background concurrent copying GC freed 6608KB AllocSpace bytes, 6(312KB) LOS objects, 49% free, 7005KB/13MB, paused 284us,138us total 101.237ms
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] created room code=868213
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=rooms/868213
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/868213/_hostLeftAt failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=rooms/868213
D/FirebaseDatabase( 1068): 🔍 Kotlin: Setting up query observe for path=.info/connected
I/flutter ( 1068): [ARENA] countdown started room=868213
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): onDisconnect().setValue at /rooms/868213/_hostLeftAt failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/flutter ( 1068): [WALLET] applying delta source=friend_room_bet_entry delta=-50 before=6229 after=6179
I/flutter ( 1068): [WALLET_LEDGER] created transactionId=arena_868213_1780108771340_TbdqWqYbpaORpWT97MZqO9JrjgV2_bet_TbdqWqYbpaORpWT97MZqO9JrjgV2 type=debit source=friend_room_bet_entry delta=-50
I/flutter ( 1068): [WALLET_LEDGER] Firestore ledger write success
I/flutter ( 1068): [ARENA_BET] debit success uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 amount=50
I/flutter ( 1068): [ARENA_BET] locked bet uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 amount=50 prizePool=100
I/flutter ( 1068): [ARENA_BET] both bets locked code=868213 prizePool=100
I/flutter ( 1068): [ARENA] game started room=868213
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=0 committed=true
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=1 committed=true
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=6 committed=true
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=5 committed=true
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/flutter ( 1068): [ARENA_WIN_CHECK] boardSize=3 requiredLineLength=3 winner=null
I/flutter ( 1068): [ARENA_DRAW] room=868213 round=1 boardSize=3 drawReplay=true signature=X|X|O|O|O|X|X|O|X
I/flutter ( 1068): [ARENA_ROUND] room=868213 resolvedKey=1:3:X|X|O|O|O|X|X|O|X result=draw
I/flutter ( 1068): [ARENA_DRAW] banner shown room=868213 round=1
I/flutter ( 1068): [ARENA] move uid=TbdqWqYbpaORpWT97MZqO9JrjgV2 cell=8 committed=true
W/RepoOperation( 1068): updateChildren at /rooms/868213 failed: DatabaseError: Permission denied
I/flutter ( 1068): [main] Unhandled zone error: [firebase_database/unknown] Firebase Database error: Permission denied
I/flutter ( 1068): #0      FirebaseDatabaseHostApi.databaseReferenceUpdate (package:firebase_database_platform_interface/src/pigeon/messages.pigeon.dart:851:7)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #1      MethodChannelDatabaseReference.update (package:firebase_database_platform_interface/src/method_channel/method_channel_database_reference.dart:119:7)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #2      ArenaRepo.applyRoundResult (package:xo_arena_neon_clash/services/arena/arena_repo.dart:654:5)
I/flutter ( 1068): <asynchronous suspension>
I/flutter ( 1068): #3      _ArenaGamePageState._resolveRound (package:xo_arena_neon_clash/screens/arena/arena_game_page.dart:655:7)
I/flutter ( 1068): <asynchronous suspension>
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
I/MSHandlerLifeCycle( 1068): isMultiSplitHandlerRequested: windowingMode=1 isFullscreen=true isPopOver=false isHidden=false skipActivityType=false isHandlerType=true this: DecorView@654d0ec[MainActivity]
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=6, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
V/MediaPlayerNative( 1068): message received msg=211, ext1=0, ext2=0
W/RepoOperation( 1068): setValue at /rooms/868213/playersPresence/TbdqWqYbpaORpWT97MZqO9JrjgV2 failed: DatabaseError: Permission denied



You are working on the Flutter/Firebase project XO Arena.

I need you to FIX the online arena system after the previous implementation introduced major sync bugs.

This is a critical bug-fix task. Do NOT redesign unrelated UI. Do NOT touch IAP, avatar store, coin store, admin dashboard, offline game, or unrelated screens.

Focus only on:

* online arena game sync
* draw replay flow
* round win/round end flow
* host/guest state consistency
* presence/connection display
* kick system
* Firebase RTDB rules for the new arena fields
* safe room resume/rejoin behavior

The current problems:

1. Draw replay is broken.
   When a round ends in draw, the “Round Draw / Replay this round” message appears, but the board does not fully reset for both players. Sometimes one device stays stuck with all cells filled and cannot continue.

2. Host and guest are not synchronized after round end.
   When the host wins, the host device moves to the next round or finishes the match normally, but the guest device stays stuck seeing the old full board. This also happens after draw and after normal win.

3. The bug happens on ALL board sizes and ALL rounds.
   It is NOT only 3x3.
   It happens on:

* 3x3
* 4x4
* 5x5

And it can happen in:

* round 1
* round 2
* round 3
* round 4
* round 5
* round 6
* round 7
* round 8

4. Kick system still has a big problem.
   The host kick action fails or does not work correctly. Logs show:

* updateChildren at /rooms/{code} failed: DatabaseError: Permission denied
* [ARENA_KICK] update failed: Firebase Database error: Permission denied

5. Presence system has RTDB permission problems.
   Logs show:

* onDisconnect().setValue at /rooms/{code}/playersPresence/{uid} failed: DatabaseError: Permission denied
* setValue at /rooms/{code}/playersPresence/{uid} failed: DatabaseError: Permission denied
* onDisconnect().setValue at /rooms/{code}/_hostLeftAt failed: DatabaseError: Permission denied

This means the new database.rules.json changes are wrong or incomplete.

6. Remove automatic leave/forfeit on app close/background.
   The previous behavior that removes the player from the room or makes them forfeit when they leave/close the app must be removed.

New required behavior:

* If host or guest closes the app / backgrounds the app / loses focus:

  * Do NOT remove them from the room.
  * Do NOT cancel the room automatically.
  * Do NOT forfeit automatically.
  * Do NOT refund automatically.
  * Do NOT payout automatically.
  * Only update their presence state to offline/connection lost if allowed.
* The room should remain active.
* The player should remain assigned as host or guest.
* If they open the app again, show a prompt:
  “You have an active room. Continue playing?”
  Buttons:

  * Continue
  * Leave Room
* If they press Continue, navigate them back into the same room/game and resync from RTDB.
* If they press Leave Room, then use the normal explicit leave logic.

Important:
Explicit Leave button should still work.
Explicit Cancel Room button should still work.
But app close/background must NOT automatically leave/cancel/forfeit.

==================================================
PART 1 — Inspect first
======================

Before editing, inspect these files carefully:

* lib/screens/arena/arena_game_page.dart
* lib/screens/arena/arena_lobby_page.dart
* lib/screens/arena/arena_join_room_page.dart
* lib/screens/arena/arena_create_room_page.dart
* lib/screens/arena/widgets/round_result_overlay.dart
* lib/screens/arena/widgets/arena_player_card.dart
* lib/screens/arena/widgets/arena_board.dart if present
* lib/screens/arena/widgets/arena_cell.dart if present
* lib/models/arena/arena_room.dart
* lib/services/arena/arena_repo.dart
* lib/services/arena/arena_bet_service.dart
* lib/services/arena/arena_presence_service.dart
* lib/services/connectivity_service.dart
* database.rules.json
* firestore.rules if arena data touches Firestore
* main/home/root navigation files that decide where user returns after app resume

Search the project for:

* _lastResolvedRound
* _lastResolvedKey
* lastRoundResult
* lastRoundEndAt
* round_draw
* round_end
* draw
* replay
* applyRoundResult
* finishMatchAtomic
* finishRoom
* cancelMatchWithRefund
* leaveRoom
* cancelRoom
* forfeit
* registerLeaveOnDisconnect
* cancelLeaveOnDisconnect
* onDisconnect
* _hostLeftAt
* _guestLeftAt
* playersPresence
* kickedUsers
* kickGuest
* AppLifecycleState
* didChangeAppLifecycleState
* inactive
* paused
* detached
* resumed
* roomCode
* activeRoom

==================================================
PART 2 — Fix RTDB rules first
=============================

The logs prove that the current RTDB rules do NOT allow the new presence and kick writes.

Fix database.rules.json so these paths work safely:

Presence:

* /rooms/{code}/playersPresence/{uid}
* user can write ONLY their own presence uid
* allowed fields:

  * state: online | weak | offline
  * lastSeen
  * lastSeenMs
  * latencyMs optional
  * updatedAt optional
* host can write their own presence
* guest can write their own presence
* random user cannot write another uid presence
* onDisconnect().setValue for own presence must be allowed

Kick:

* /rooms/{code}/kickedUsers/{uid}
* only hostUid of that room can write kick entries
* guest cannot kick
* random user cannot kick
* only allowed fields:

  * kickedAt
  * until
  * byUid
  * reason
* byUid must equal auth.uid
* auth.uid must equal room.hostUid

Room updates for kick:

* host must be allowed to update guestUid / guest / guestReady / status if needed for lobby-only kick
* keep this secure
* do not allow host to cheat during playing
* kick must be allowed only when status is waiting, ready, or countdown
* if status is playing, kick write must be rejected or UI must not write it

Remove or stop writing:

* _hostLeftAt
* _guestLeftAt
  unless rules are intentionally added and the fields are still needed.
  Since new requirement says app close should NOT leave/forfeit/cancel, these fields are probably no longer needed and should be removed from code and rules.

After rules change:

* deploy rules
* verify no more permission-denied for playersPresence
* verify no more permission-denied for kickGuest

==================================================
PART 3 — Remove automatic leave/forfeit/cancel on lifecycle
===========================================================

Remove the previous lifecycle behavior that causes app close/background to leave the room, cancel the room, or forfeit.

Specifically:

* In arena_lobby_page.dart and arena_game_page.dart, inspect WidgetsBindingObserver / didChangeAppLifecycleState.
* Remove any call on paused/inactive/detached to:

  * leaveRoom
  * cancelRoom
  * finishRoom
  * finishMatchAtomic
  * cancelMatchWithRefund
  * forfeit
  * registerLeaveOnDisconnect that writes _hostLeftAt/_guestLeftAt
* Remove onDisconnect actions that mark host left/guest left as actual room leave.
* Keep only presence updates if rules allow:

  * on paused/inactive/detached: presence state offline or lastSeen stale
  * on resumed: presence state online
* Do not mutate room membership on lifecycle.
* Do not clear hostUid or guestUid on lifecycle.
* Do not change status on lifecycle.
* Do not touch bet/payout/refund on lifecycle.

Explicit actions remain:

* if user taps Leave Room, use explicit leave logic
* if host taps Cancel Room, cancel room explicitly
* if match finished normally, payout/summary works normally

Add logs:
[ARENA_LIFECYCLE] state=<state> action=presence_only room=<code> uid=<uid>
[ARENA_LIFECYCLE] ignored_auto_leave room=<code> uid=<uid>

==================================================
PART 4 — Add active room resume prompt
======================================

If a user leaves the app or navigates away and later opens the app, they should be able to return to the active room.

Implement an active room resume system:

Data:

* Store locally the last active room code and role while user is in lobby/game.
* Example SharedPreferences keys:

  * arena.activeRoomCode
  * arena.activeRoomRole
  * arena.activeRoomStatus
  * arena.activeRoomUpdatedAt

When entering lobby/game:

* save active room locally.

When explicit leave/cancel/finished:

* clear active room locally.

On app startup / home hub / main online screen:

* check local activeRoomCode.
* fetch /rooms/{code}.
* if room exists and status is not finished/cancelled/archived:

  * if current uid is still hostUid or guestUid:
    show modal:
    “You have an active room. Continue playing?”
    Buttons:

    * Continue
    * Leave Room
  * Continue:

    * if room status is waiting/ready/countdown => navigate to lobby
    * if room status is playing/round_end/round_draw => navigate to game
    * resync from RTDB
  * Leave Room:

    * run explicit leave logic
    * clear local active room
* if room no longer exists or user is not in it:

  * clear local active room silently

Important:

* Do not show this modal repeatedly every frame.
* Show once per resume/startup.
* If user presses Continue, no double navigation.
* If user is already inside that room, do not show the modal.

Add logs:
[ARENA_RESUME] found active room=<code> status=<status>
[ARENA_RESUME] continue room=<code>
[ARENA_RESUME] clear stale room=<code>

==================================================
PART 5 — Fix round state as single source of truth
==================================================

The host and guest are diverging after draw/win. This means the client UI is probably using local timers/local banners/local _room state incorrectly, or the host updates the room but guest does not process the transition.

Fix this with a single-source-of-truth room state machine in RTDB.

Every round resolution must be written to RTDB in a way both clients can observe.

Required room fields:

* status: playing | round_end | finished | cancelled
* currentRound
* roundMaps or map for each round
* board
* turnUid
* winnerUid
* winnerLine
* scoreHost
* scoreGuest
* lastRoundResult: host | guest | draw
* lastRoundWinnerUid: uid or null
* lastRoundEndAt
* roundNonce or roundVersion
* boardVersion or moveVersion optional

Important:
Add a monotonically increasing roundVersion/transitionVersion if not already present.
Example:
roundVersion increments every time a round ends or a new replay/next round starts.

Why:
The guest device must not rely on local “did I already show this banner” logic only.
Both devices should react to room.roundVersion and room.status changes.

==================================================
PART 6 — Correct draw flow
==========================

Draw flow must work on all boards and all rounds.

For every board size:

* 3x3 draw = board full with no 3-in-row
* 4x4 draw = board full with no 4-in-row
* 5x5 draw = board full with no 5-in-row

For every round 1–8:

* draw must replay same round
* currentRound must stay unchanged
* scoreHost/scoreGuest unchanged
* board resets on both devices
* both host and guest see the reset
* no payout
* no refund
* no match finish

Preferred flow:

1. Host detects terminal board.
2. Host writes:

   * status = round_end or round_draw
   * lastRoundResult = draw
   * lastRoundWinnerUid = null
   * lastRoundEndAt = ServerValue.timestamp
   * winnerLine = []
   * roundVersion += 1
3. Both clients show draw overlay based on RTDB fields.
4. Only host schedules/executes the replay transition after delay or when both continue:

   * status = playing
   * board = empty board of same boardSize
   * turnUid = deterministic starter
   * winnerUid = null
   * winnerLine = []
   * lastRoundResult = null or keep history but not blocking
   * currentRound unchanged
   * roundVersion += 1
5. Guest must not independently reset the board.
6. Guest only listens and renders the RTDB board.

Important:
If local _room is stale, always rebuild from RTDB snapshot.
Never keep showing old filled board after RTDB board reset.

Add logs:
[ARENA_DRAW] detected room=<code> round=<round> boardSize=<size> version=<v>
[ARENA_DRAW] overlay shown room=<code> uid=<uid> version=<v>
[ARENA_DRAW] replay reset written room=<code> round=<round> boardSize=<size> version=<v>
[ARENA_DRAW] client received reset room=<code> uid=<uid> boardEmpty=<true|false> version=<v>

==================================================
PART 7 — Correct normal win / next round flow
=============================================

Normal win flow is also broken on guest side.

Required:
If host wins or guest wins a round:

* both devices see round end overlay
* both devices see winner highlight
* score increments exactly once
* after transition:

  * if match continues, both devices move to next round
  * board resets on both devices
  * currentRound increments on both devices
  * board size changes according to roundMaps on both devices
  * turnUid is correct
* if match has only one round or winner condition reached:

  * both devices navigate/show match finished
  * payout happens exactly once
  * summary written exactly once
  * guest must not stay stuck on old full board

Preferred flow:

1. Host detects win.
2. Host writes terminal state:

   * status = round_end
   * lastRoundResult = host or guest
   * lastRoundWinnerUid = winnerUid
   * winnerUid = winnerUid
   * winnerLine = correct line
   * scoreHost/scoreGuest updated once
   * lastRoundEndAt = ServerValue.timestamp
   * roundVersion += 1
3. Both clients show overlay from RTDB.
4. Only host performs transition:

   * if match continues:

     * currentRound += 1
     * board = empty board for next round boardSize
     * status = playing
     * winnerUid = null
     * winnerLine = []
     * turnUid = correct next starter
     * roundVersion += 1
   * if match finished:

     * status = finished
     * finalWinnerUid = winnerUid
     * payout/summary idempotently
5. Guest never performs independent next-round transition.
6. Guest must clear old board from RTDB update.

Add logs:
[ARENA_ROUND_END] room=<code> result=<host|guest|draw> winner=<uid|null> round=<round> version=<v>
[ARENA_NEXT_ROUND] room=<code> newRound=<round> boardSize=<size> version=<v>
[ARENA_FINISH] room=<code> winner=<uid> payoutApplied=<true|false>

==================================================
PART 8 — Fix dedupe without blocking replay or guest sync
=========================================================

The previous fix used:
currentRound + boardSize + board.join('|')

This is better than currentRound only, but it may still cause problems if the client evaluates empty boards or stale board states incorrectly.

Update dedupe rules:

* Only host evaluates terminal boards.
* Only evaluate when status == playing.
* Only evaluate when board is terminal:

  * winner exists OR full board draw
* Dedupe key should include:

  * roomCode
  * currentRound
  * boardSize
  * board signature
  * moveVersion/roundVersion if available
* Do not set dedupe for non-terminal boards.
* When RTDB board resets, clear local terminal overlays and local selected state.
* When room.roundVersion changes, allow new evaluation if the board later becomes terminal.

Important:
The dedupe must prevent double processing of the same terminal board, but must never block:

* replayed draw round
* next round
* final round
* guest UI receiving updates

Add:
[ARENA_DEDUPE] skip key=<key> reason=<reason>
[ARENA_DEDUPE] accept key=<key>

==================================================
PART 9 — Confirm win logic for 3x3 / 4x4 / 5x5
==============================================

Verify and if needed fix:

3x3:

* winLength = 3
* 3 horizontal/vertical/diagonal wins

4x4:

* winLength = 4
* 4 horizontal/vertical/diagonal wins
* 3 in a row must NOT win

5x5:

* winLength = 5
* 5 horizontal/vertical/diagonal wins
* 3 or 4 in a row must NOT win

Draw:

* 3x3 full 9 with no winner
* 4x4 full 16 with no winner
* 5x5 full 25 with no winner

Add or keep logs:
[ARENA_WIN_CHECK] boardSize=<size> requiredLineLength=<size> winner=<uid|null>

==================================================
PART 10 — Fix kick system properly
==================================

Kick should be lobby-only.

Required:

* Host can kick guest only when status is:

  * waiting
  * ready
  * countdown
* Host cannot kick in playing.
* Guest cannot kick.
* Random user cannot kick.
* Kick writes must pass RTDB rules.
* Kicked guest sees message and exits lobby/game if they are still there.
* Kicked guest cannot rejoin for 60 seconds.
* After 60 seconds, guest can rejoin if room is still open.

Fix:

* Make UI hide Kick button if status == playing.
* Make repo reject kick if status == playing.
* Make rules reject kick if status == playing.
* Make kick update only allowed fields.
* Do not use a big updateChildren that rules reject because unrelated fields are included.
* Split updates if needed:

  1. write kickedUsers/{guestUid}
  2. update guest fields allowed by rules
* Or update database.rules.json to allow exactly the combined multi-location update safely.

Add logs:
[ARENA_KICK] attempt host=<uid> guest=<uid> room=<code> status=<status>
[ARENA_KICK] success room=<code>
[ARENA_KICK] blocked reason=<reason>
[ARENA_JOIN_BLOCKED] kickedCooldown remainingMs=<ms>

==================================================
PART 11 — Presence should show status only, not force leave
===========================================================

Presence display:

* online = green
* weak = orange
* offline = red/gray

Presence must not:

* remove player
* cancel room
* forfeit
* refund
* payout

Presence may:

* show “Opponent connection lost”
* show “Waiting for reconnect”
* show “Offline”
* disable moves only if it is not the player’s turn or if the app cannot write
* keep the room state intact

If a player returns:

* mark online
* continue from latest RTDB state

If opponent is offline for a long time:

* for now, do NOT auto-forfeit unless explicitly requested.
* show status only.

==================================================
PART 12 — Add robust client resync
==================================

The guest staying stuck means snapshot handling is not fully refreshing local UI.

Fix:

* Every RTDB room snapshot should update _room immediately.
* The board widget must render _room.board from RTDB only.
* Do not keep a separate local board copy that can get stale.
* If a local animation overlay is shown, it must not block the underlying RTDB board update forever.
* When status changes from round_end/draw to playing:

  * close overlay
  * clear winner/draw banner
  * rebuild board
  * allow moves again
* When currentRound changes:

  * reset local selected cells/animation state
  * rebuild board using new boardSize

Add logs on every room snapshot:
[ARENA_ROOM_SNAPSHOT] uid=<uid> room=<code> status=<status> round=<round> boardSize=<size> filled=<n> version=<v> result=<result>

==================================================
PART 13 — Do not create new money bugs
======================================

Do not change IAP.

For arena bet:

* No payout on draw replay.
* No refund on draw replay.
* No auto payout/refund on app background.
* Explicit leave/cancel should use existing safe bet logic.
* Match finish payout must be idempotent.
* Never double refund.
* Never double payout.
* Never double write wallet ledger.

Add logs:
[ARENA_BET_GUARD] action=<payout|refund|skip> reason=<reason> room=<code>

==================================================
PART 14 — Manual test checklist
===============================

Run:
flutter clean
flutter pub get
flutter analyze
flutter run

Use the detected device id from `flutter devices`, not an old missing id.

Manual tests on two devices/accounts:

A. RTDB rules:

* Create room.
* Confirm no permission-denied for /playersPresence.
* Confirm no permission-denied for kickGuest.
* Confirm no permission-denied for onDisconnect presence.
* If any permission denied appears, fix rules before continuing.

B. Draw replay:
For 3x3:

* draw round 1
* overlay appears on both devices
* same round restarts on both
* board clears on both
* then win
* both devices move correctly

For 4x4:

* draw
* replay
* confirm 3 in a row does NOT win
* 4 in a row wins
* both devices move correctly

For 5x5:

* draw
* replay
* confirm 3/4 in a row do NOT win
* 5 in a row wins
* both devices move correctly

C. Round coverage:

* Test round 1.
* Test middle round like round 4.
* Test final configured round, including round 6/7/8 if available.

D. Guest sync:

* Host wins.
* Guest must not stay stuck.
* Guest board must clear/advance/finish exactly like host.
* Guest must see finish if match finished.

E. Host sync:

* Guest wins.
* Host must not stay stuck.
* Host board must clear/advance/finish exactly like guest.

F. App background/close:

* Host backgrounds app.

* Host remains in room.

* Guest sees host offline/connection lost only.

* No cancel, no forfeit, no payout.

* Host returns and gets Continue prompt.

* Continue returns to room.

* Guest backgrounds app.

* Guest remains in room.

* Host sees guest offline/connection lost only.

* No leave, no forfeit, no payout.

* Guest returns and gets Continue prompt.

G. Kick:

* Host can kick guest in lobby.
* Guest cannot kick.
* Kick not visible during playing.
* Kicked guest blocked for 60 seconds.
* Kick writes pass rules.

==================================================
PART 15 — Final report
======================

When done, report:

* exact root causes found
* files changed
* rules changes
* lifecycle changes removed
* how active room resume works
* how draw replay is now synchronized
* how normal round win is now synchronized
* how guest stuck board bug was fixed
* how kick permission denied was fixed
* flutter analyze result
* any remaining manual test risks

Do not claim success unless the permission denied logs are gone and both host/guest sync tests are verified.
