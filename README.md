# Tidal · Liquid Lab

Godot **4.7.2** 的 2D 液體模擬小遊戲，無外部套件。

## 執行

用 Godot 4.7.2 匯入 `project.godot`，按 **F6/F5** 執行主場景。

雲端環境：

```bash
export PATH=/workspace/.local/bin:$PATH
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
export XDG_CACHE_HOME=/workspace/.cache
cd /workspace/LiquidSimulator_godot
godot --editor --path .
```

圖形編輯器與遊戲視窗需要可用的顯示服務。無顯示器的雲端可執行下列測試。

## 操作

- 在正方形內按住滑鼠左鍵拖曳，快速改變方向可以產生波浪。
- 右側 **Viscosity** 滑桿調整黏稠度：左側接近水，右側接近糖漿。
- **Space** 或 Pause / Play：暫停／繼續。
- **R** 或 Reset liquid：重設容器位置與液體，保留黏稠度設定。

## 為什麼使用粒子流體

液體沒有單一最適合的 Godot 內建「液體物件」。`RigidBody2D` 適合剛體，數百個碰撞圓球通常呈現砂粒或彈珠效果，因此本專案使用自訂的粒子流體求解器；`Node2D` 負責呈現，粒子位置、速度與鄰居資料由獨立求解器維護。

- 486 個粒子；120 Hz 固定模擬步長。
- 空間雜湊搜尋鄰居，對稱雙密度鬆弛修正壓力。
- XSPH 速度擴散控制黏滯程度。
- 移動容器以相對壁面速度處理碰撞；粒子保留慣性，呈現晃動、堆積、波浪。
- SubViewport 密度貼圖加上閾值著色器融合粒子，呈現連續水體。

這是即時遊戲用的近似流體模型，並非工程 CFD。容器採平移、封閉四壁，不支援旋轉或溢出；黏稠度為藝術控制值而非 Pa·s。高速拖曳有速度上限以維持穩定；較慢電腦在大量粒子運算時可能降低模擬速度。

## 驗證

```bash
godot --headless --path . --editor --import
godot --headless --path . --script tests/viscosity_test.gd
godot --headless --path . -- --smoke-test
```

黏度測試比較相同初始速度下的相對動能，確認高黏度確實抑制粒子間相對運動。整合測試以兩種黏稠度和持續移動的容器運行 720 次模擬步，確認粒子數、有限數值、容器邊界和實際運動。無視窗測試不代表已人工驗證畫面與滑鼠操作。
