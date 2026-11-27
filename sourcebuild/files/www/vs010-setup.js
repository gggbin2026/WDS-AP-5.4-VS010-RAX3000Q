/* r27 常用设置控制台：网桥页 / AP 页 / LuCI「常用设置」页共用。
   写入与维护端点都在 LuCI admin 树下（sysauth 保护）；未登录只读、操作锁定。
   目标：常用设置全部在这两个界面完成，高深操作才回 LuCI 原生界面。 */
(function(){
  var BASE='/cgi-bin/luci/admin/status/vs010_setup';
  /* file:// 离线演示 / 反代场景 location.host 可能为空，兜底用默认管理地址 */
  var HOST=location.host||'172.10.10.241';
  var K=['mode','role','ap_ssid','ap_key','ap2_ssid','ap2_key','ap5_ssid','ap5_key',
         'wds_ssid','wds_key','peer_ssid','peer_key','peer_bssid',
         'ch5g','ch24g','htmode','txpower','wmm','mumimo','weak_rssi','weak_timeout',
         'mgmt_ip','mgmt_mask','hostname','stp','ntp_server','ntp_interval','theme'];
  var D={ap_ssid:'VS010-AP',ap_key:'AP123456',wds_ssid:'WDS-Bridge-Z',wds_key:'WDS123456',
         ch5g:'auto',ch24g:'auto',htmode:'HT160',txpower:'auto',wmm:'1',mumimo:'1',
         weak_rssi:'-70',weak_timeout:'10',mgmt_mask:'255.255.252.0',stp:'1',
         ntp_server:'172.10.10.254',ntp_interval:'300',theme:'argon'};
  var box=document.getElementById('vs010-setup'); if(!box) return;
  var PAGE=box.getAttribute('data-mode')||'auto';
  var MODE='wds', ROLE='ap', AUTH=false, ST={};

  var CSS='<style>'
   +'.vsf *{box-sizing:border-box}.vsf{font-size:13.5px;line-height:1.6;max-width:960px}'
   +'.vsf .nav{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0 14px;padding:8px;border-radius:999px;'
     +'background:linear-gradient(90deg,#1677d2,#7a5cf0);box-shadow:0 2px 10px rgba(20,60,120,.18)}'
   +'.vsf .nav a{color:#fff;text-decoration:none;padding:5px 12px;border-radius:999px;font-size:12.5px;'
     +'background:rgba(255,255,255,.14);white-space:nowrap}'
   +'.vsf .nav a:hover{background:rgba(255,255,255,.3)}'
   +'.vsf .nav .sp{flex:1}'
   +'.vsf h3{margin:0 0 8px;font-size:14.5px;display:flex;align-items:center;gap:8px}'
   +'.vsf h3 em{font-style:normal;font-size:11px;font-weight:500;opacity:.6}'
   +'.vsf .sec{border:1px solid #dbe3ec;border-radius:9px;padding:12px 14px;margin:10px 0;'
     +'background:#fafbfd;box-shadow:0 1px 3px rgba(20,40,80,.05)}'
   +'.vsf .row{display:flex;flex-wrap:wrap;gap:10px 16px;margin:8px 0;align-items:flex-end}'
   +'.vsf label.f{display:flex;flex-direction:column;gap:4px;min-width:185px;flex:1}'
   +'.vsf label.f>span{font-weight:600}'
   +'.vsf label.f i{font-style:normal;opacity:.7;font-size:11.5px}'
   +'.vsf input[type=text],.vsf input[type=password],.vsf select{'
     +'padding:7px 9px;border:1px solid #c9d2dc;border-radius:999px;font-size:13.5px;background:#fff;color:#1b2430;width:100%}'
   +'.vsf input:disabled,.vsf select:disabled{background:#eef1f4;color:#8a94a0}'
   +'.vsf .sw{display:inline-flex;align-items:center;gap:12px;font-weight:700;white-space:nowrap}'
   +'.vsf .sw input{display:none}'
   +'.vsf .tr{width:178px;height:36px;border-radius:999px;position:relative;cursor:pointer;'
     +'background:linear-gradient(90deg,#1677d2 0%,#1677d2 50%,#7a5cf0 50%,#7a5cf0 100%);'
     +'box-shadow:inset 0 1px 4px rgba(0,0,0,.22)}'
   +'.vsf .th{position:absolute;top:3px;left:3px;width:86px;height:30px;border-radius:999px;'
     +'background:#fff;box-shadow:0 2px 6px rgba(0,0,0,.3);transition:transform .2s;'
     +'display:flex;align-items:center;justify-content:center;font-size:11.5px;font-weight:800;color:#1b2430}'
   +'.vsf .sw input:checked + .tr .th{transform:translateX(86px)}'
   +'.vsf .sw input:disabled + .tr{opacity:.5;cursor:not-allowed}'
   +'.vsf .lbl{display:flex;justify-content:space-between;width:178px;font-size:11.5px;opacity:.75}'
   +'.vsf button{padding:8px 15px;border:0;border-radius:999px;background:#1677d2;color:#fff;'
     +'font-size:13px;font-weight:700;cursor:pointer}'
   +'.vsf button.ghost{background:#eaf1fa;color:#15518f}'
   +'.vsf button.warnb{background:#fdeaea;color:#a61b1b}'
   +'.vsf button:disabled{background:#9aa7b4;color:#fff;cursor:not-allowed}'
   +'.vsf .msg{margin-top:10px;padding:10px 12px;border-radius:999px;background:#eef6ff;'
     +'color:#124a86;white-space:pre-wrap;word-break:break-all;display:none}'
   +'.vsf .lock{padding:12px;border-radius:999px;background:#fff4e5;color:#8a4b00;'
     +'border:1px solid #f0c78d;margin:10px 0;font-weight:600}'
   +'.vsf .warn{color:#b91c1c;text-decoration:underline;font-weight:700;margin:10px 0}'
   +'.vsf .out{margin-top:8px;padding:10px;border-radius:6px;background:#111827;color:#d1fae5;'
     +'font:12px/1.55 monospace;white-space:pre-wrap;word-break:break-all;max-height:280px;overflow:auto;display:none}'
   +'.vsf .hint{font-size:12px;opacity:.72;margin:6px 0}'
   /* ★ r28：页面主体是深色主题，白底卡片里的标题/标签/滑块必须强制深色，
      否则会被页面 h3 / label 的浅色规则盖成几乎看不见（截图实测到的真 BUG） */
   +'.vsf .sec h3,.vsf .sec h3 em,.vsf label.f>span,.vsf label.f i,'
   +'.vsf .sw,.vsf .sw span,.vsf .lbl{color:#1b2430}'
   +'.vsf .sec h3 em{opacity:.6}'
   +'.vsf label.f i{opacity:.7}'

   +'</style>';

  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){
    return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
  function f(name,label,hint,val,type){
    return '<label class="f"><span>'+label+'</span><input type="'+(type||'text')+
      '" id="f_'+name+'" value="'+esc(val)+'"><i>'+hint+'</i></label>';
  }
  function sw(name,left,right,checked){
    return '<div class="sw"><span>'+left+'</span><label style="display:block;margin:0">'+
      '<input type="checkbox" id="f_'+name+'"'+(checked?' checked':'')+'>'+
      '<span class="tr"><span class="th"></span></span></label><span>'+right+'</span></div>';
  }
  function sel(name,label,hint,opts,val){
    var o='';for(var i=0;i<opts.length;i++){o+='<option value="'+esc(opts[i])+'"'+
      (String(opts[i])===String(val)?' selected':'')+'>'+esc(opts[i])+'</option>';}
    return '<label class="f"><span>'+label+'</span><select id="f_'+name+'">'+o+'</select><i>'+hint+'</i></label>';
  }
  function sec(title,sub,body){return '<div class="sec"><h3>'+title+' <em>'+sub+'</em></h3>'+body+'</div>';}

  function render(st){
    ST=st||{}; var w=ST.mode?ST.mode:MODE, r=ST.role?ST.role:ROLE;
    var v=function(k){var x=ST[k];return (x===undefined||x===null||x==='')?(D[k]||''):x;};
    var five=['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140','144','149','153','157','161','165'];
    var two=['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
    var h=CSS+'<div class="vsf">';
    h+='<div class="nav"><a href="/bridge/">网桥状态</a><a href="/ap/">AP 状态</a>'
      +'<a href="/cgi-bin/luci/admin/status/vs010_ports">网口状态</a>'
      +'<a href="/cgi-bin/luci/admin/status/vs010_console">控制台</a><span class="sp"></span>'
      +'<a href="/cgi-bin/luci/">⚙ 高级设置后台</a></div>';

    h+=sec('① 工作模式','一个固件内置双模式，切完菜单与界面自动跟着换',
      '<div class="row">'+sw('mode','AP 模式 · .241','WDS 桥接 · 主 .241 / 客 .242',w==='wds')+'</div>'
      +'<div class="lbl"><span>左：AP</span><span>右：WDS 桥接</span></div>'
      +'<div class="hint">切换会清 LuCI 菜单缓存 + reload uhttpd + 重跑首启配置，<b>不重启机器</b>；'
      +'2 秒后自动打开对应界面，主题「状态」菜单也只显示当前模式那一套。</div>','');

    h+=sec('② WDS 主 / 客户端','左主右客 · 客户端可填桥接目标',
      '<div id="sec_wds"><div class="row">'+sw('role','WDS 主 WDS-Z .241','WDS 客 WDS-K .242',r==='sta')+'</div>'
      +'<div class="lbl"><span>左：WDS 主</span><span>右：WDS 客户端</span></div>'
      +'<div class="row">'+f('wds_ssid','WDS 主端 SSID','主端广播的桥接名称','','text').replace('value=""','value="'+esc(v('wds_ssid'))+'"')
      +f('wds_key','WDS 主端密码','8–63 字节 / psk2+ccmp','','text').replace('value=""','value="'+esc(v('wds_key'))+'"')+'</div>'
      +'<div class="row">'+f('peer_ssid','桥接目标 SSID','客户端连哪个主端；留空跟随主端名','','text').replace('value=""','value="'+esc(v('peer_ssid'))+'"')
      +f('peer_key','桥接目标密码','必须与 WDS 主一致','','text').replace('value=""','value="'+esc(v('peer_key'))+'"')
      +f('peer_bssid','主端 BSSID（可选）','aa:bb:cc:dd:ee:ff，定向桥接','','text').replace('value=""','value="'+esc(v('peer_bssid'))+'"')+'</div></div>');

    h+=sec('③ AP 无线名称与密码','2.4G / 5G 可各自独立；留空则用统一值',
      '<div id="sec_ap"><div class="row">'
      +f('ap_ssid','统一 SSID','默认按机型 VS010-AP / RAX3000Q-AP','','text').replace('value=""','value="'+esc(v('ap_ssid'))+'"')
      +f('ap_key','统一密码','8–63 字节 / 默认 AP123456','','text').replace('value=""','value="'+esc(v('ap_key'))+'"')+'</div>'
      +'<div class="row">'
      +f('ap2_ssid','2.4G SSID（独立）','留空 = 用统一 SSID','','text').replace('value=""','value="'+esc(v('ap2_ssid'))+'"')
      +f('ap2_key','2.4G 密码（独立）','留空 = 用统一密码','','text').replace('value=""','value="'+esc(v('ap2_key'))+'"')+'</div>'
      +'<div class="row">'
      +f('ap5_ssid','5G SSID（独立）','留空 = 用统一 SSID','','text').replace('value=""','value="'+esc(v('ap5_ssid'))+'"')
      +f('ap5_key','5G 密码（独立）','留空 = 用统一密码','','text').replace('value=""','value="'+esc(v('ap5_key'))+'"')+'</div></div>');

    h+=sec('④ WiFi 射频参数','信道 / 频宽 / 功率 / WMM / MU-MIMO / 弱信号',
      '<div class="row">'
      +sel('ch5g','5G 信道','auto = QSDK 原生 ACS 自动选道',five,v('ch5g'))
      +sel('ch24g','2.4G 信道','AP 模式用；网桥模式 2.4G radio 关闭',two,v('ch24g'))
      +sel('htmode','5G 频宽','HT160 = QSDK 的 160MHz 满速；可选 HT80/HT40',['HT160','HT80','HT40'],v('htmode'))
      +'</div><div class="row">'
      +f('txpower','发射功率','auto 或 1–30 dBm','','text').replace('value=""','value="'+esc(v('txpower'))+'"')
      +f('weak_rssi','SSID 信号剔除值','低于此值剔除，-100…-30 dBm','','text').replace('value=""','value="'+esc(v('weak_rssi'))+'"')
      +f('weak_timeout','最低连接保持时间','弱信号持续多少秒拒绝连接，1–60','','text').replace('value=""','value="'+esc(v('weak_timeout'))+'"')
      +'</div><div class="row">'
      +sel('wmm','WMM','两种模式都生效',['1','0'],v('wmm'))
      +sel('mumimo','MU-MIMO','he_ulmumimo / he_mubfer',['1','0'],v('mumimo'))
      +'</div>');

    h+=sec('⑤ 网络与本机','管理地址 / 设备名 / STP / 时间同步',
      '<div class="row">'
      +f('mgmt_ip','管理 IP','改动后 3 秒网络重载，请用新地址重开','','text').replace('value=""','value="'+esc(v('mgmt_ip')|| (ST.ip||'172.10.10.241'))+'"')
      +f('mgmt_mask','子网掩码','默认 255.255.252.0 (/22)','','text').replace('value=""','value="'+esc(v('mgmt_mask'))+'"')
      +f('hostname','设备名','字母数字 - _，最长 32','','text').replace('value=""','value="'+esc(v('hostname'))+'"')
      +'</div><div class="row">'
      +sel('stp','生成树 STP','网桥/AP 都防环',['1','0'],v('stp'))
      +f('ntp_server','NTP 服务器','内网时间源，只做客户端','','text').replace('value=""','value="'+esc(v('ntp_server'))+'"')
      +f('ntp_interval','同步间隔（秒）','60–3600，默认 300','','text').replace('value=""','value="'+esc(v('ntp_interval'))+'"')
      +'</div><div class="hint">🔒 改 root 登录密码、固件升级、VLAN / 静态路由等复杂操作请进 '
      +'<a href="/cgi-bin/luci/">高级设置后台</a>：开机脚本会把密码归一为出厂值，页面改了反而会打架。</div>');

    h+=sec('⑥ 外观','Argon 主题',
      '<div class="row">'+sel('theme','主题','2.4.3 是最后一个 Lua 兼容版；切换不重启',['argon','argon243'],v('theme'))+'</div>');

    h+=sec('⑦ 维护与自检','机器狗 / DHCP Snooping / 日志 / 一键自检',
      '<div class="row" id="actrow">'
      +'<button class="ghost" data-act="selfcheck">一键自检</button>'
      +'<button class="ghost" data-act="wds_status">WDS 配对状态</button>'
      +'<button class="ghost" data-act="watchdog_status">机器狗状态</button>'
      +'<button class="ghost" data-act="watchdog_dryrun">机器狗演练</button>'
      +'<button class="ghost" data-act="watchdog_on">启用机器狗</button>'
      +'<button class="warnb" data-act="watchdog_off">停用机器狗</button>'
      +'<button class="ghost" data-act="guard_status">Snooping 状态</button>'
      +'<button class="ghost" data-act="guard_monitor">Snooping 只监测</button>'
      +'<button class="ghost" data-act="guard_on">Snooping 阻断</button>'
      +'<button class="ghost" data-act="log">查看日志</button>'
       +'</div>'
       +'<div class="hint" style="margin:8px 0 2px;padding:7px 9px;border-radius:999px;background:#eef6ff">'
       +'🔧 <b>高级设置后台（OpenWrt / LuCI）直达路径</b>：<code>/cgi-bin/luci/</code> → '
       +'<b>http://'+HOST+'/cgi-bin/luci/</b>（右上角按钮同效；不带尾斜杠 <code>/cgi-bin/luci</code> 亦可）。'
       +'<br>r28 起根路径 <code>/</code> 是状态页自动跳转，<b>不再直达 LuCI</b>；日志里也会带上这条路径。</div>'
       +'<div class="out" id="f_out"></div>'
      +'<div class="hint">动作走 LuCI 白名单枚举（固定命令、无参数），未登录全部锁定；'
      +'<b>不提供「开启 DHCP 服务端」按钮</b>，避免内网地址混乱。</div>');

    if(!AUTH){
      h+='<div class="lock">🔒 未登录：可以浏览当前参数，但<b>保存与维护已锁定</b>。'
        +'<a href="/cgi-bin/luci/" style="color:#8a4b00;font-weight:800"> 点此登录高级设置后台 </a>后回到本页即可操作（从主题菜单进入时已自动登录）。</div>';
    }
    h+='<div class="warn">🔴 WDS 主 / 客户端两端都绝不能开 DHCP 服务端（本机 WDS 与 AP 均已关闭），内网只允许上级一台 DHCP</div>';
    h+='<div class="row"><button id="f_save"'+(AUTH?'':' disabled')+'>保存并联动应用到后台</button>'
      +'<span style="font-size:12px;opacity:.75">写 user.cfg(600) + wireless/network/system/luci，一次 wifi reload，开机重读，重启不丢</span></div>';
    h+='<div class="msg" id="f_msg"></div></div>';
    box.innerHTML=h;

    function vis(){
      var m=document.getElementById('f_mode').checked?'wds':'ap';
      var wd=document.getElementById('sec_wds'), ap=document.getElementById('sec_ap');
      if(wd) wd.style.display=(m==='wds')?'':'none';
      if(ap) ap.style.display=(m==='ap')?'':'none';
    }
    var mEl=document.getElementById('f_mode'); if(mEl) mEl.onchange=vis; vis();
    var btn=document.getElementById('f_save'); if(btn) btn.onclick=save;
    var acts=document.querySelectorAll('#actrow button');
    for(var i=0;i<acts.length;i++) acts[i].onclick=doAct;
  }

  function doAct(){
    var out=document.getElementById('f_out'), a=this.getAttribute('data-act');
    if(!AUTH){out.style.display='block';out.textContent='🔒 未登录，维护操作已锁定';return;}
    out.style.display='block';out.textContent='执行中…';
    var fd=new FormData();fd.append('a',a);
    fetch(BASE+'/act',{method:'POST',body:fd,credentials:'same-origin',cache:'no-store'})
      .then(function(r){return r.text();}).then(function(t){
        var j={};try{j=JSON.parse(t);}catch(e){}
        var tip=(a==='log'||a==='selfcheck')
          ? '🔧 高级设置后台（OpenWrt / LuCI）直达：http://'+HOST+'/cgi-bin/luci/'
            +'　（右上角「高级设置后台」同效；根路径 / 现为状态页跳转）\n'
            +'────────────────────────────────────────\n'
          : '';
        out.textContent=tip+(j.out||j.msg||t.slice(0,2000));
      }).catch(function(e){out.textContent='失败：'+e;});
  }

  function save(){
    var btn=document.getElementById('f_save'),msg=document.getElementById('f_msg');
    if(!btn||!AUTH) return;
    btn.disabled=true;msg.style.display='block';msg.textContent='正在保存并联动写入后台…';
    var fd=new FormData();
    var m=document.getElementById('f_mode').checked?'wds':'ap';
    var r=document.getElementById('f_role').checked?'sta':'ap';
    fd.append('mode',m);fd.append('role',r);
    for(var i=0;i<K.length;i++){
      var k=K[i];if(k==='mode'||k==='role')continue;
      var e=document.getElementById('f_'+k);fd.append(k,e?e.value:'');
    }
    fetch(BASE+'/save',{method:'POST',body:fd,credentials:'same-origin',cache:'no-store'})
      .then(function(r){return r.text();})
      .then(function(t){
        var j={};try{j=JSON.parse(t);}catch(e){}
        msg.textContent=j.msg||('返回异常：'+t.slice(0,200));
        msg.style.background=j.ok?'#e8f7ee':'#fdeaea';
        msg.style.color=j.ok?'#146c3a':'#a61b1b';
        if(j.ok){
          if(j.mode&&j.mode!==m){
            msg.textContent+='\n🔴 模式已切换，2 秒后自动打开 '+(j.mode==='ap'?'/ap/':'/bridge/')+'（主题菜单也已刷新）';
            setTimeout(function(){location.href=(j.mode==='ap')?'/ap/':'/bridge/';},2000);
          } else if(j.ip&&location.hostname!==j.ip){
            msg.textContent+='\n🔴 若管理地址变为 '+j.ip+'，请用新地址重新打开页面。';
          }
        }
        btn.disabled=false;
      })
      .catch(function(e){msg.textContent='保存失败：'+e+'\n请确认已登录 LuCI 后重试';btn.disabled=false;});
  }

  function boot(){
    fetch('/cgi-bin/vs010?_='+Date.now(),{cache:'no-store'})
      .then(function(r){return r.json();})
      .then(function(j){
        MODE=(j&&j.mode==='ap')?'ap':'wds';
        if(PAGE!=='auto'&&PAGE!==MODE){
          box.innerHTML='<div class="card" style="padding:16px;font-size:14px">'
            +'当前固件运行在 <b>'+(MODE==='ap'?'AP':'WDS 网桥')+'</b> 模式，本页是 <b>'+(PAGE==='ap'?'AP':'网桥')+'</b> 界面，设置不适用。<br>'
            +'请从主题「状态」菜单进入 <b>'+(MODE==='ap'?'AP 状态':'网桥状态')+'</b>，或打开 '
            +'<a href="/cgi-bin/luci/admin/status/vs010_setup">常用设置</a>。'
            +'<br><b>2 秒后自动切换到对应界面…</b></div>';
          // ★ r27：整页也不串——手动输错网址时自动跳到当前模式的界面
          setTimeout(function(){location.href=(MODE==='ap')?'/ap/':'/bridge/';},2000);
          return null;
        }
        return fetch(BASE+'/probe?_='+Date.now(),{credentials:'same-origin',cache:'no-store'})
          .then(function(r){return r.text();})
          .then(function(t){var k={};try{k=JSON.parse(t);}catch(e){}AUTH=!!k.ok;
            if(!AUTH){render(null);return null;}
            return fetch(BASE+'/state?_='+Date.now(),{credentials:'same-origin',cache:'no-store'})
              .then(function(r){return r.json();}).then(render);
          });
      })
      .catch(function(){MODE='wds';AUTH=false;render(null);});
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot); else boot();
})();
