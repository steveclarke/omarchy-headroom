import QtQuick
import QtTest
import "app" as App
import "app/Providers.js" as Providers

Item {
  width: 400; height: 650
  QtObject {
    id:host
    property var catalog: [{id:"claude",name:"Claude Code",icon:"claude.svg"},{id:"codex",name:"Codex",icon:"codex.svg"}]
    property var preferences: Providers.normalize(catalog,{})
    property var providers: []
    property double nowMs: Date.now()
    property bool reject: false
    property int saves: 0
    function savePreferences(value) { if(reject)return false; preferences=Providers.normalize(catalog,value);saves++;return true }
  }
  App.SettingsView {id:view;width:400;service:host;ink:"#222222";dim:"#555555"}
  TestResult {id:results}
  TestCase {
    onCompletedChanged: if (completed) console.log("DRAG_RESULTS", results.passCount, results.failCount)
    name:"ProviderDrag"
    when:true
    function test_outside_cancels() {
      var end=dragStart("claude","codex")
      mouseMove(view,view.width+40,end.y,40,Qt.LeftButton)
      mouseRelease(view,view.width+40,end.y);wait(30)
      compare(host.saves,0)
    }
    function init() {host.preferences=Providers.normalize(host.catalog,{});host.saves=0;host.reject=false;view.begin();wait(30)}
    function dragStart(id,target) {
      var handle=findChild(view,"reorder-"+id), other=findChild(view,"reorder-"+target)
      verify(handle!==null);verify(other!==null)
      var end=other.mapToItem(view,other.width/2,other.height/2)
      mousePress(handle,handle.width/2,handle.height/2)
      mouseMove(view,end.x,end.y,40,Qt.LeftButton)
      wait(30)
      return end
    }
    function test_drag_down_saves_on_release() {
      view.setShowInBar("claude",false);host.saves=0
      var end=dragStart("claude","codex")
      compare(host.saves,0)
      mouseRelease(view,end.x,end.y);wait(30)
      compare(host.preferences.providerOrder.join(","),"codex,claude")
      compare(host.preferences.providers.claude.display,"panel")
      compare(host.saves,1)
    }
    function test_drag_up() {
      var end=dragStart("codex","claude")
      mouseRelease(view,end.x,end.y);wait(30)
      compare(host.preferences.providerOrder.join(","),"codex,claude")
    }
    function test_escape_cancels() {
      var end=dragStart("claude","codex")
      keyClick(Qt.Key_Escape)
      mouseRelease(view,end.x,end.y);wait(30)
      compare(host.saves,0)
      compare(host.preferences.providerOrder.join(","),"claude,codex")
    }
    function test_rejected_drop_keeps_order() {
      host.reject=true
      var end=dragStart("claude","codex")
      mouseRelease(view,end.x,end.y);wait(30)
      compare(host.preferences.providerOrder.join(","),"claude,codex")
      verify(view.error!=="")
    }
    function test_cost_drag_and_visibility() {
      var handle=findChild(view,"reorder-cost"), other=findChild(view,"reorder-codex")
      var end=other.mapToItem(view,other.width/2,other.height+50)
      mousePress(handle,handle.width/2,handle.height/2)
      mouseMove(view,end.x,end.y,40,Qt.LeftButton)
      compare(host.saves,0)
      mouseRelease(view,end.x,end.y);wait(30)
      compare(Providers.panelOrder(host.preferences).join(","),"claude,codex,cost")
      view.setCosts(false);wait(30)
      verify(findChild(view,"reorder-cost")!==null)
      view.setCosts(true);wait(30)
      compare(host.preferences.costPosition,2)
      findChild(view,"reorder-cost").forceActiveFocus()
      keyClick(Qt.Key_Up);wait(30)
      compare(Providers.panelOrder(host.preferences).join(","),"claude,cost,codex")
    }
    function test_keyboard_reorders() {
      findChild(view,"reorder-codex").forceActiveFocus()
      keyClick(Qt.Key_Up);wait(30)
      compare(host.preferences.providerOrder.join(","),"codex,claude")
    }
  }
}
