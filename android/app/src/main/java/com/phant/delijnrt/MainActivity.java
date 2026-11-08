package com.phant.delijnrt;

import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

/**
 * 系统返回键按页面层级回退：
 * 先把返回交给页面的 window.dlBack()（详情 → 上一级列表 → 清空搜索），
 * 不再先折叠抽屉；只有它返回 false（已在顶层）时才真正结束 Activity。
 */
public class MainActivity extends BridgeActivity {

    private boolean backPending = false;

    @Override
    public void onBackPressed() {
        if (backPending) return;   // 连按：等上一次 JS 结果回来再处理
        WebView webView = bridge != null ? bridge.getWebView() : null;
        if (webView == null) {
            finishFromBack();
            return;
        }
        backPending = true;
        webView.evaluateJavascript(
            "(function(){try{return window.dlBack?window.dlBack()===true:false}catch(e){return false}})()",
            value -> {
                backPending = false;
                if (value != null && value.trim().equals("true")) return;
                finishFromBack();
            });
    }

    private void finishFromBack() {
        super.onBackPressed();
    }
}
