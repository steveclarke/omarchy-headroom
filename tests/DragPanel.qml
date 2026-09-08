import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "app" as App
import "app/Model.js" as Model
import "app/Costs.js" as Costs
import "app/Providers.js" as Providers
ShellRoot {
  QtObject {
    id: data
    property var catalog: [{"id": "claude", "name": "Claude Code", "shortName": "Claude", "icon": "claude.svg", "color": "#d77b5f", "collector": "omarchy-agent-usage-claude", "headline": "weekly", "warningWindows": ["weekly", "fable-weekly"], "costs": true, "loginHint": "Run claude auth login, then refresh."}, {"id": "codex", "name": "Codex", "shortName": "Codex", "icon": "openai.svg", "color": "#279b80", "collector": "omarchy-agent-usage-codex", "headline": "weekly", "warningWindows": ["weekly"], "costs": true, "loginHint": "Run codex login, then refresh."}]
    property var preferences: Providers.normalize(catalog,{})
    property double nowMs: Date.now()
    property string demoMode: "demo"
    property bool refreshing: false
    property bool costsRefreshing: false
    property int costPeriod: 0
    property var selectedIds: Providers.selected(catalog,preferences,false,false)
    property double nextRefreshAt: nowMs + 300000
    property double nextCostRefreshAt: nowMs + 120000
    property var providers: Providers.selected(catalog,preferences,false,false).map(function(id) {return Object.assign({},Providers.find(Model.demo(nowMs,demoMode),id),Providers.find(catalog,id))})
    property var costIds: preferences.showCosts ? Providers.selected(catalog,preferences,false,true) : []
    property var costs: Costs.demo(nowMs,demoMode)
    function savePreferences(value) {preferences=Providers.normalize(catalog,value);return true}
    function refresh() {}
  }
  QtObject {
    id: host
    property string position: "top"
    property int barSize: 26
    property color barForeground: Color.foreground
    property var activePopout: null
    property var shell: host
    property var clickTargets: []
    function serviceFor(name) {return data}
    function requestPopout(owner) {activePopout=owner}
    function releasePopout(owner) {activePopout=null}
    function showTooltip(item,text) {}
    function hideTooltip(item) {}
  }
  PanelWindow {
    id: anchorWindow
    anchors {top:true;left:true;right:true}
    implicitHeight: 26
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "headroom-preview-anchor"
    Item {id:anchor; x:parent.width/2-50; width:100; height:26}
  }
  App.Panel {id:details;bar:host;anchorItem:anchor}

  TestResult {id:results}
  TestCase {
    id:dragTests
    name:"MainPanelDrag"
    when:true
    onCompletedChanged: if(completed) console.log("MAIN_DRAG_RESULTS",results.passCount,results.failCount)
    function init() {
      data.demoMode="demo"
      data.preferences=Providers.normalize(data.catalog,{showCosts:false})
      details.hideSettings();details.open();wait(100)
    }
    function findHandle(id) {
      for (var i=0;i<details.data.length;i++) {
        var obj=details.data[i], found=findChild(obj,"reorder-main-"+id)
        if(found)return found
        if(obj.contentItem && obj.contentItem.length!==undefined) {
          for(var j=0;j<obj.contentItem.length;j++) {
            found=findChild(obj.contentItem[j],"reorder-main-"+id)
            if(found)return found
          }
        }
      }
      return null
    }
    function perform(id,target) {
      var handle=findHandle(id),other=findHandle(target)
      verify(handle!==null,"source handle");verify(other!==null,"target handle")
      var surface=handle.QsWindow.window.contentItem[0]
      var end=other.mapToItem(surface,other.width/2,other.height/2)
      mousePress(handle,handle.width/2,handle.height/2)
      mouseMove(surface,end.x,end.y,50,Qt.LeftButton)
      compare(data.preferences.providerOrder.join(","),"claude,codex")
      mouseRelease(surface,end.x,end.y);wait(50)
      compare(data.preferences.providerOrder.join(","),"codex,claude")
    }
    function test_cost_main_drag() {
      data.preferences=Providers.normalize(data.catalog,{providers:{claude:{display:"off"}}})
      wait(100)
      var handle=findHandle("cost"),other=findHandle("codex")
      verify(handle!==null);verify(other!==null)
      var surface=handle.QsWindow.window.contentItem[0]
      var end=other.mapToItem(surface,other.width/2,other.height+70)
      mousePress(handle,handle.width/2,handle.height/2)
      mouseMove(surface,end.x,end.y,50,Qt.LeftButton)
      compare(data.preferences.costPosition,0)
      mouseRelease(surface,end.x,end.y);wait(50)
      compare(Providers.panelOrder(data.preferences).join(","),"claude,codex,cost")
      handle=findHandle("cost")
      handle.forceActiveFocus();keyClick(Qt.Key_Up);wait(50)
      compare(Providers.panelOrder(data.preferences).join(","),"claude,cost,codex")
    }
    function test_refresh_countdown_binding() {
      var surface=findHandle("claude").QsWindow.window.contentItem[0]
      var label=findChild(surface,"refresh-countdown")
      verify(label!==null)
      data.demoMode="";data.nextRefreshAt=data.nowMs+120000;wait(30)
      compare(label.text,"Next update in 2 min")
      data.nowMs+=61000;wait(30)
      compare(label.text,"Next update in <1 min")
      verify(label.contentWidth <= label.width,"Countdown fits without truncation")
      data.refreshing=true;wait(30);compare(label.text,"Updating…")
      data.nextRefreshAt=data.nowMs+300000;data.refreshing=false;wait(30)
      compare(label.text,"Next update in 5 min")
    }
    function test_anchor_stays_fixed_until_reopened() {
      var originalX=anchor.x, originalWidth=anchor.width
      var popup=null
      for (var i=0;i<details.data.length;i++) if (details.data[i].cardOrigin !== undefined) popup=details.data[i]
      verify(popup!==null)
      var cardX=popup.cardOrigin.x
      var heldX=details.heldAnchor.x, heldWidth=details.heldAnchor.width
      anchor.x+=90;anchor.width=40;wait(30)
      compare(popup.cardOrigin.x,cardX)
      compare(details.heldAnchor.x,heldX)
      compare(details.heldAnchor.width,heldWidth)
      details.close();wait(30);details.open();wait(50)
      compare(details.heldAnchor.x,anchor.x)
      compare(details.heldAnchor.width,40)
      anchor.x=originalX;anchor.width=originalWidth
    }
    function test_main_down() {perform("claude","codex")}
    function test_main_up() {perform("codex","claude")}
  }
}
