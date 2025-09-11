import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
// 修复：字体模块改为从 @ohos.font 引入，确保在Canvas文本绘制中可被识别
import font from '@ohos.font';
import { QuoteDataManager, Quote } from '../common/QuoteDataManager';
import wallpaper from '@ohos.wallpaper'; // 导入壁纸设置API
import image from '@ohos.multimedia.image'; // 导入图像处理API
import display from '@ohos.display'; // 获取屏幕尺寸用于回退
import picker from '@ohos.file.picker'; // 导入文件选择器API
import fs from '@ohos.file.fs'; // 导入文件系统API
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'; // 导入权限管理API
import bundleManager from '@ohos.bundle.bundleManager'; // 导入包管理API

/**
 * 路由参数接口
 */
interface RouterParams {
  index?: number;
  quote?: Quote | string; // 支持Quote对象或JSON字符串
}

/**
 * 文字样式接口
 */
interface TextStyle {
  fontSize: number;
  lineHeight: number;
}

// 添加颜色候选数组，与 web 版本的 COLORS 保持一致
const WALLPAPER_COLORS: string[] = [
  "#E57373", "#F06292", "#BA68C8", "#9575CD", "#7986CB",
  "#64B5F6", "#4DB6AC", "#81C784", "#DCE775", "#FFD54F",
  "#5488BC", "#917C6B", "#AA9F7C", "#A29296", "#515E68"
];

/**
 * 壁纸预览页面
 * 基于wallpaper.html实现壁纸预览、Canvas绘制分层波浪背景、触摸滑动切换语录等功能
 * 并使其样式更接近 web 版本 (壁纸.html)
 */
@Entry
@Component
struct WallpaperPage {
  // 页面状态
  @State quotes: Quote[] = [];
  @State currentQuoteIndex: number = 0;
  @State isControlsVisible: boolean = true;
  @State isLoading: boolean = true;
  @State isDownloadVisible: boolean = false;
  @State downloadState: 'confirm' | 'loading' | 'success' = 'confirm';
  // 触摸相关状态
  @State touchStartX: number = 0;
  @State touchStartY: number = 0;
  // Canvas相关
  // 根据HarmonyOS标准：预先创建CanvasRenderingContext2D对象
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;
  // 保留 canvasElement 作为实际绘图使用的上下文引用
  private canvasElement: CanvasRenderingContext2D | null = null;
  @State currentQuoteColor: string = '#4A90E2'; // 默认颜色
  // 服务实例
  private quoteManager = QuoteDataManager.getInstance(getContext(this));

  /**
   * 页面初始化
   */
  async aboutToAppear() {
    console.log('壁纸预览界面加载完成');
    // 注册自定义字体（确保在绘制前完成注册）
    try {
      await font.registerFont({
        familyName: 'FangZhengFont',
        familySrc: $rawfile('fangzheng.ttf')
      });
      console.log('自定义字体 FangZhengFont 注册成功');
    } catch (e) {
      console.warn('自定义字体注册失败，将回退系统字体:', e);
    }
    await this.loadQuotes();
    this.initializeIndex();
  }

  /**
   * 加载语录数据
   */
  async loadQuotes() {
    try {
      this.quotes = await this.quoteManager.getAllQuotes();
      console.log('语录数据加载完成:', this.quotes.length, '条');
      // 如果没有语录，使用默认语录
      if (this.quotes.length === 0) {
        const defaultQuote: Quote = {
          id: 'default',
          text: '生活不是等待风暴过去，而是学会在雨中翩翩起舞。',
          tags: [],
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };
        this.quotes = [defaultQuote];
      }
      this.isLoading = false;
    } catch (error) {
      console.error('加载语录失败:', error);
      // 使用默认语录作为备选
      const defaultQuote: Quote = {
        id: 'default',
        text: '生活不是等待风暴过去，而是学会在雨中翩翩起舞。',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      this.quotes = [defaultQuote];
      this.isLoading = false;
    }
  }

  /**
   * 新增：根据当前语录索引更新颜色
   */
  private updateCurrentQuoteColor() {
    if (this.quotes.length > 0 && this.currentQuoteIndex >= 0) {
      // 使用取模运算确保索引在颜色数组范围内
      const colorIndex = this.currentQuoteIndex % WALLPAPER_COLORS.length;
      this.currentQuoteColor = WALLPAPER_COLORS[colorIndex];
      console.log(`当前语录索引: ${this.currentQuoteIndex}, 使用颜色: ${this.currentQuoteColor}`);
    } else {
      // 如果没有语录或索引无效，使用默认颜色
      this.currentQuoteColor = '#4A90E2';
    }
  }

  /**
   * 初始化索引
   * 修改：在设置索引后，计算并设置当前语录的颜色
   * 优化：支持解析JSON字符串形式的quote参数
   */
  initializeIndex() {
    const params = router.getParams() as RouterParams;
    if (params) {
      // 优先使用传递的quote参数
      if (params.quote) {
        let targetQuote: Quote | null = null;
        
        // 处理quote参数：可能是Quote对象或JSON字符串
        if (typeof params.quote === 'string') {
          try {
            // 解析JSON字符串为Quote对象
            targetQuote = JSON.parse(params.quote) as Quote;
            console.log('WallpaperPage: 成功解析JSON字符串形式的quote参数:', targetQuote);
          } catch (parseError) {
            console.error('WallpaperPage: 解析quote JSON字符串失败:', parseError, params.quote);
            // 解析失败时使用默认处理
            targetQuote = null;
          }
        } else {
          // 直接使用Quote对象
          targetQuote = params.quote;
          console.log('WallpaperPage: 使用Quote对象形式的参数:', targetQuote);
        }
        
        // 如果成功获取到targetQuote，查找对应的索引
        if (targetQuote) {
          const quoteIndex = this.quotes.findIndex(q => q.id === targetQuote!.id);
          if (quoteIndex >= 0) {
            this.currentQuoteIndex = quoteIndex;
            console.log(`WallpaperPage: 找到匹配的语录，索引为: ${quoteIndex}`);
          } else {
            // 如果没找到对应的quote，将传递的quote添加到列表开头
            this.quotes.unshift(targetQuote);
            this.currentQuoteIndex = 0;
            console.log('WallpaperPage: 未找到匹配语录，已添加到列表开头');
          }
        }
      } else if (typeof params.index === 'number' &&
        params.index >= 0 && params.index < this.quotes.length) {
        this.currentQuoteIndex = params.index;
        console.log(`WallpaperPage: 使用索引参数: ${params.index}`);
      }
    }
    // 新增：根据当前索引设置颜色
    this.updateCurrentQuoteColor();
  }

  /**
   * 十六进制颜色转RGB
   */
  private hexToRgb(hex: string): number[] {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [
      parseInt(result[1], 16),
      parseInt(result[2], 16),
      parseInt(result[3], 16)
    ] : [0, 0, 0];
  }

  /**
   * 调整颜色亮度（与wallpaper.html的adjustColor函数保持一致）
   */
  private adjustColor(rgb: number[], factor: number = 1.0): number[] {
    const r = rgb[0];
    const g = rgb[1];
    const b = rgb[2];
    return [
      Math.max(0, Math.min(255, Math.floor(r * factor))),
      Math.max(0, Math.min(255, Math.floor(g * factor))),
      Math.max(0, Math.min(255, Math.floor(b * factor)))
    ];
  }

  /**
   * 绘制分层波浪背景（与wallpaper.html的drawLayeredWaves函数保持一致）
   * 修改：使用 this.canvasElement 并确保其行为与web版本完全一致
   * 用于预览显示，不包含水印
   */
  private drawLayeredWaves(baseColor: string) {
    this.drawLayeredWavesInternal(baseColor, false);
  }

  /**
   * 绘制带水印的分层波浪背景，专用于下载功能
   * @param baseColor 基础颜色
   */
  private drawLayeredWavesWithWatermark(baseColor: string) {
    this.drawLayeredWavesInternal(baseColor, true);
  }

  /**
   * 内部绘制方法，根据参数决定是否添加水印
   * @param baseColor 基础颜色
   * @param includeWatermark 是否包含水印
   */
  private drawLayeredWavesInternal(baseColor: string, includeWatermark: boolean) {
    // 检查Canvas是否就绪
    if (!this.canvasElement || this.canvasWidth <= 0 || this.canvasHeight <= 0) {
      console.warn(`Canvas未就绪，无法绘制. Element: ${!!this.canvasElement}, Width: ${this.canvasWidth}, Height: ${this.canvasHeight}`);
      return;
    }
    const ctx = this.canvasElement; // 类型已收窄
    const width = this.canvasWidth;
    const height = this.canvasHeight;
    const baseRgb = this.hexToRgb(baseColor);

    // 清空画布
    ctx.clearRect(0, 0, width, height);
    // 统一壁纸图片背景色为 #E6E6E6（与原型一致，且避免JPEG透明变黑）
    ctx.fillStyle = '#E6E6E6';
    ctx.fillRect(0, 0, width, height);

    // 参数设置（与wallpaper.html保持一致）
    const numLayers = 6;
    const baseFromBottom = Math.floor(height * 0.32);
    const gapPerLayer = Math.floor(height * 0.035);
    const baseWavelength = 420;
    const baseAmplitude = 52;
    const step = 6;

    // 绘制6层波浪（从上到下，颜色逐渐加深）
    for (let i = 0; i < numLayers; i++) {
      // 颜色调整（与wallpaper.html的adjust_color逻辑一致）
      const colorFactor = 1 - i * 0.06;
      const adjustedRgb = this.adjustColor(baseRgb, colorFactor);
      // 透明度计算（与wallpaper.html一致：25 + i*38，转换为0-1范围）
      const alpha = Math.min(255, 25 + i * 38) / 255;
      ctx.fillStyle = `rgba(${adjustedRgb[0]}, ${adjustedRgb[1]}, ${adjustedRgb[2]}, ${alpha})`;

      // 波浪参数（与wallpaper.html一致）
      const wavelength = baseWavelength * (1.0 + i * 0.03);
      const amplitude = baseAmplitude * (1.0 + i * 0.05);
      const phase = Math.random() * Math.PI * 2; // 随机相位

      // 层偏移计算（与wallpaper.html一致）
      const layerOffset = height - (baseFromBottom - i * gapPerLayer);

      // 创建波浪路径
      ctx.beginPath();
      // 绘制正弦波（与wallpaper.html逻辑一致）
      const points: number[][] = [];
      for (let x = 0; x <= width; x += step) {
        const y = layerOffset - amplitude * Math.sin(2 * Math.PI * x / wavelength + phase);
        points.push([x, y]);
      }

      // 开始绘制路径
      if (points.length > 0) {
        ctx.moveTo(points[0][0], points[0][1]);
        for (let j = 1; j < points.length; j++) {
          ctx.lineTo(points[j][0], points[j][1]);
        }
      }

      // 封闭路径到底部（与wallpaper.html一致）
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
    }
    
    // 绘制语录文字内容
    this.drawQuoteText(ctx, width, height);
    
    // 根据参数决定是否添加水印
    if (includeWatermark) {
      this.drawWatermark(ctx, width, height);
    }
    
    console.log(`Canvas drawing completed successfully. 水印: ${includeWatermark ? '已添加' : '未添加'}`);
  }

  /**
   * 在Canvas上绘制语录文字内容
   * @param ctx Canvas绘图上下文
   * @param width Canvas宽度
   * @param height Canvas高度
   */
  private drawQuoteText(ctx: CanvasRenderingContext2D, width: number, height: number) {
    if (!this.quotes[this.currentQuoteIndex]) {
      return;
    }

    const quoteText = this.quotes[this.currentQuoteIndex].text;
    const textStyle = this.getTextStyle(quoteText);

    ctx.save(); // 保存当前绘图状态

    // 设置字体和样式 - 使用注册的字体族名
    ctx.font = `${textStyle.fontSize + 20}px FangZhengFont, Microsoft YaHei, sans-serif`;
    ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(0, 0, 0, 0.96)'; // 使用黑色并提升可读性
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    // 添加文字阴影，参考 web 版本文本阴影以增强对比度
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowBlur = 4;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 2;
    
    // 计算文字位置（与UI层Text组件位置一致）
    const textX = width / 2;
    const textY = height * 0.25; // 对应UI层的25%位置
    
    // 处理文字换行
    const maxWidth = width - 64; // 左右各32px边距
    const lines = this.wrapText(ctx, quoteText, maxWidth);
    
    // 绘制多行文字
    const lineHeight = (textStyle.fontSize) * 0.8; // 1.2倍行高
    const totalHeight = lines.length * lineHeight;
    const startY = textY - totalHeight / 2;
    
    for (let i = 0; i < lines.length; i++) {
      const y = startY + i * lineHeight;
      ctx.fillText(lines[i], textX, y);
    }
    
    ctx.restore(); // 恢复绘图状态
    console.log(`语录文字绘制完成: ${lines.length}行, 字体大小: ${textStyle.fontSize}px`);
  }
  
  /**
   * 文字自动换行处理
   * @param ctx Canvas绘图上下文
   * @param text 要处理的文字
   * @param maxWidth 最大宽度
   * @returns 换行后的文字数组
   */
  private wrapText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
    const lines: string[] = [];
    let currentLine = '';
    
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const testLine = currentLine + char;
      const metrics = ctx.measureText(testLine);
      
      if (metrics.width > maxWidth && currentLine !== '') {
        lines.push(currentLine);
        currentLine = char;
      } else {
        currentLine = testLine;
      }
    }
    
    if (currentLine !== '') {
      lines.push(currentLine);
    }
    
    return lines;
  }

  /**
   * 在Canvas左下角绘制「语录壁纸」水印标识
   * @param ctx Canvas绘图上下文
   * @param width Canvas宽度
   * @param height Canvas高度
   */
  private drawWatermark(ctx: CanvasRenderingContext2D, width: number, height: number) {
    // 设置水印样式
    const watermarkText = '语录壁纸';
    const fontSize = Math.max(30, Math.min(width, height) * 0.06); // 进一步增大水印字体尺寸
    const padding = fontSize * 0.8; // 距离边缘的间距
    
    ctx.save(); // 保存当前绘图状态
    
    // 设置字体和样式 - 使用注册的字体族名
    ctx.font = `${fontSize +30}px 'fangzheng', 'Microsoft YaHei', sans-serif`;
    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)'; // 更明显
    ctx.textAlign = 'left';
    ctx.textBaseline = 'bottom';
    
    // 添加文字阴影效果
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowOffsetX = 1;
    ctx.shadowOffsetY = 1;
    ctx.shadowBlur = 2;
    
    // 在左下角绘制水印文字
    ctx.fillText(watermarkText, padding, height - padding);
    
    ctx.restore(); // 恢复绘图状态
    console.log(`水印绘制完成: ${watermarkText}, 字体大小: ${fontSize}px`);
  }

  /**
   * 根据字数自动调整文字样式 (更接近web版本)
   * 修复：返回正确的行高数值，避免文字重叠
   * 增大字体尺寸以提升可读性
   */
  private getTextStyle(content: string): TextStyle {
    const length = content.length;
    if (length <= 15) {
      // 显著增大字体，调整行高，更符合web效果
      return { fontSize: 44, lineHeight: 62 }; // 44 * ~1.4
    } else if (length <= 30) {
      return { fontSize: 38, lineHeight: 56 }; // 38 * ~1.47
    } else if (length <= 50) {
      return { fontSize: 32, lineHeight: 50 }; // 32 * ~1.56
    } else {
      // 对于长文本，适当减小字体但保持较大尺寸
      return { fontSize: 28, lineHeight: 46 }; // 28 * ~1.64
    }
  }

  /**
   * 切换到指定语录
   * 修改：在切换后更新颜色并重绘
   */
  private switchToQuote(index: number) {
    if (index < 0 || index >= this.quotes.length) return;
    this.currentQuoteIndex = index;
    // 新增：更新颜色
    this.updateCurrentQuoteColor();
    // 重新绘制波浪背景
    setTimeout(() => {
      // 修改：使用当前语录的颜色绘制
      if (this.quotes[index]) {
        this.drawLayeredWaves(this.currentQuoteColor); // 使用动态颜色
      }
    }, 50); // 稍微延迟确保状态更新
  }

  /**
   * 上一条语录
   */
  private previousQuote() {
    const newIndex = this.currentQuoteIndex > 0 ? this.currentQuoteIndex - 1 : this.quotes.length - 1;
    this.switchToQuote(newIndex);
  }

  /**
   * 下一条语录
   */
  private nextQuote() {
    const newIndex = this.currentQuoteIndex < this.quotes.length - 1 ? this.currentQuoteIndex + 1 : 0;
    this.switchToQuote(newIndex);
  }

  /**
   * 切换控制栏显示/隐藏
   */
  private toggleControls() {
    this.isControlsVisible = !this.isControlsVisible;
  }

  /**
   * 返回上一页
   */
  private goBack() {
    router.back();
  }

  /**
   * 设置壁纸 - 实现真正的系统壁纸设置功能
   */
  private async setWallpaper() {
    try {
      console.log('开始设置壁纸:', this.quotes[this.currentQuoteIndex]);
      // 等待画布就绪（必要时回退到屏幕尺寸）
      const ready = await this.ensureCanvasReady(2000); // 增加超时时间
      if (!ready) {
        promptAction.showToast({
          message: '壁纸预览未准备就绪，请稍后重试',
          duration: 2000
        });
        return;
      }
      promptAction.showToast({
        message: '正在生成壁纸...',
        duration: 2000
      });

      // 确保绘制的是当前状态
      this.drawLayeredWaves(this.currentQuoteColor);
      // 等待绘制完成
      await new Promise<void>((resolve) => setTimeout(resolve, 300));

      // 修复：通过局部常量收窄类型，避免空指针，并进行最终检查
      const validCanvasContext = this.canvasElement;
      if (!validCanvasContext) {
        console.error('Canvas上下文未就绪，无法导出图像数据 (在setWallpaper中)');
        promptAction.showToast({
          message: '生成壁纸失败，请稍后重试',
          duration: 2000
        });
        return;
      }

      // 将Canvas内容转换为ImageData
      const imageData = validCanvasContext.getImageData(0, 0, this.canvasWidth, this.canvasHeight);
      // 创建PixelMap
      const pixelMap = await this.createPixelMapFromImageData(imageData);
      // 设置为系统壁纸
      await this.applySystemWallpaper(pixelMap);
      console.log('壁纸设置成功');
      promptAction.showToast({
        message: '壁纸设置成功！',
        duration: 2000
      });
    } catch (err) {
      console.error('设置壁纸失败:', err);
      let errMsg = '壁纸设置失败，请重试';
      if (err instanceof Error) {
        errMsg = err.message || errMsg;
      }
      promptAction.showToast({
        message: errMsg,
        duration: 2000
      });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 等待Canvas就绪，确保已获取上下文且尺寸有效；如尺寸无效则回退为屏幕分辨率
   * @param timeoutMs 最大等待时长
   * @returns 是否就绪
   */
  private async ensureCanvasReady(timeoutMs: number = 1000): Promise<boolean> {
    const start = Date.now();
    while ((!this.canvasElement || this.canvasWidth <= 0 || this.canvasHeight <= 0) && Date.now() - start < timeoutMs) {
      if (!this.canvasElement && this.canvasContext) {
        this.canvasElement = this.canvasContext;
        console.log('ensureCanvasReady: Assigned canvasElement from canvasContext during wait loop.');
      }
      // 仅等待UI回调(onAreaChange)提供的真实尺寸，避免与真实画布缓冲尺寸不一致
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    const ready = !!this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0;
    console.log(`ensureCanvasReady: ready=${ready}, w=${this.canvasWidth}, h=${this.canvasHeight}`);
    return ready;
  }

  /**
   * 将ImageData转换为PixelMap
   * 功能：把Canvas返回的RGBA像素数据转换为BGRA_8888并创建PixelMap，避免颜色通道错乱
   * 参数：
   *  - imageData: Canvas的像素数据对象，data为RGBA顺序的Uint8ClampedArray
   * 返回：Promise<image.PixelMap>
   */
  private async createPixelMapFromImageData(imageData: ImageData): Promise<image.PixelMap> {
    try {
      // 将Canvas返回的RGBA数据转换为BGRA，以匹配HarmonyOS Image模块默认处理格式，避免颜色偏差
      // 含义：许多设备/版本在createPixelMap时默认按照BGRA_8888处理缓冲区，提前转换可确保显示正确
      const src: Uint8ClampedArray = imageData.data;
      const total: number = src.length;
      const bgra: Uint8Array = new Uint8Array(total);
      for (let i = 0; i < total; i += 4) {
        bgra[i] = src[i + 2];     // B <- R
        bgra[i + 1] = src[i + 1]; // G <- G
        bgra[i + 2] = src[i];     // R <- B
        bgra[i + 3] = src[i + 3]; // A <- A
      }

      // 使用强类型对象，符合 ArkTS 结构化类型校验要求
      const size: image.Size = { width: this.canvasWidth, height: this.canvasHeight };
      const opts: image.InitializationOptions = {
        size,
        editable: true,
        pixelFormat: image.PixelMapFormat.BGRA_8888
      };
      const pixelMap: image.PixelMap = await image.createPixelMap(bgra.buffer, opts);

      return pixelMap;
    } catch (err) {
      // 结构化日志，便于排查问题
      console.error(JSON.stringify({
        level: 'ERROR',
        module: 'WallpaperPage',
        func: 'createPixelMapFromImageData',
        message: 'Failed to create PixelMap from ImageData',
        error: (err as Error)?.message ?? String(err)
      }));
      throw (err instanceof Error ? err : new Error(String(err)));
    }
  }

  /**
   * 检查壁纸设置权限
   */
  private async checkWallpaperPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      
      // 检查bundleInfo和appInfo是否存在
      if (!bundleInfo || !bundleInfo.appInfo) {
        console.error('无法获取应用信息，bundleInfo或appInfo为null');
        return false;
      }
      
      const tokenId = bundleInfo.appInfo.accessTokenId;
      if (!tokenId) {
        console.error('无法获取accessTokenId');
        return false;
      }
      
      const grantStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.SET_WALLPAPER');
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      console.error('检查壁纸权限失败:', error);
      return false;
    }
  }

  /**
   * 设置系统壁纸（API 兼容封装）
   * - 先检查权限，再调用 setWallpaper；对于不支持或失败场景，抛出明确错误给上层处理
   * - 说明：从 API 9 起壁纸相关能力调整为系统接口，第三方应用可能无法直接设置
   * @param pixelMap 已生成的像素图
   */
  private async applySystemWallpaper(pixelMap: image.PixelMap): Promise<void> {
    try {
      // 检查权限
      const hasPermission = await this.checkWallpaperPermission();
      if (!hasPermission) {
        throw new Error('应用缺少SET_WALLPAPER权限，无法设置壁纸');
      }

      console.log('开始设置系统壁纸...');
      await wallpaper.setWallpaper(pixelMap, wallpaper.WallpaperType.WALLPAPER_SYSTEM);
      console.log('系统壁纸设置成功');
      return;
    } catch (err) {
      // 结构化错误日志
      console.error(JSON.stringify({
        level: 'ERROR',
        module: 'WallpaperPage',
        func: 'applySystemWallpaper',
        message: 'Failed to set wallpaper',
        error: (err as Error)?.message ?? String(err)
      }));
      
      // 标准化错误，交由上层 UI 统一提示与降级（如引导用户手动设置或仅提供下载）
      let message = '设置壁纸失败：当前系统可能限制第三方应用直接设置壁纸，请保存图片后前往系统相册或壁纸设置中手动设置。';
      if (err instanceof Error && err.message) {
        message += ` 详情：${err.message}`;
      }
      throw new Error(message);
    }
  }

  /**
   * 编辑语录
   * 修复：确保传递序列化后的 JSON 字符串给 EditPage，与 Index.ets 和 EditPage.ets 的实现保持一致
   */
  private editQuote() {
    const quote = this.quotes[this.currentQuoteIndex];
    console.log('WallpaperPage: 尝试编辑语录:', quote); // 调试日志
    if (quote) { // 确保语录对象存在
      let quoteParam: string = '';
      try {
        // 关键修改：序列化语录对象为 JSON 字符串
        quoteParam = JSON.stringify(quote);
        console.log('WallpaperPage: 序列化后的语录参数:', quoteParam); // 调试日志
      } catch (serializeError) {
        console.error('WallpaperPage: 序列化语录对象失败:', serializeError, quote);
        promptAction.showToast({
          message: '数据准备失败，无法编辑'
        });
        return; // 终止执行
      }
      // 执行页面跳转
      router.pushUrl({
        url: 'pages/EditPage',
        params: {
          mode: 'edit',
          // 关键修改：传递序列化后的字符串
          quote: quoteParam
        }
      }).then(() => {
        console.log('WallpaperPage: 成功跳转到编辑页面');
      }).catch((error: Error) => {
        console.error('WallpaperPage: 跳转编辑页面失败:', error);
        promptAction.showToast({
          message: '跳转失败，请重试'
        });
      });
    } else {
      console.warn('WallpaperPage: 尝试编辑语录，但当前语录为空');
      promptAction.showToast({
        message: '无法编辑当前语录'
      });
    }
  }

  /**
   * 下载壁纸到本地
   */
  private async downloadWallpaper() {
    try {
      console.log('开始下载壁纸:', this.quotes[this.currentQuoteIndex]);
      
      // 等待画布就绪
      const ready = await this.ensureCanvasReady(2000);
      if (!ready) {
        promptAction.showToast({
          message: '壁纸预览未准备就绪，请稍后重试',
          duration: 2000
        });
        return;
      }
      
      promptAction.showToast({
        message: '正在生成壁纸...',
        duration: 2000
      });
      
      // 确保绘制的是当前状态（包含水印）
      this.drawLayeredWavesWithWatermark(this.currentQuoteColor);
      // 等待绘制完成
      await new Promise<void>((resolve) => setTimeout(resolve, 300));
      
      // 获取Canvas内容
      const validCanvasContext = this.canvasElement;
      if (!validCanvasContext) {
        console.error('Canvas上下文未就绪，无法导出图像数据');
        promptAction.showToast({
          message: '生成壁纸失败，请稍后重试',
          duration: 2000
        });
        return;
      }
      
      // 将Canvas内容转换为ImageData
      const imageData = validCanvasContext.getImageData(0, 0, this.canvasWidth, this.canvasHeight);
      
      // 创建PixelMap
      const pixelMap = await this.createPixelMapFromImageData(imageData);
      
      // 将PixelMap转换为图片数据
      const imagePackerApi = image.createImagePacker();
      const packOpts: image.PackingOption = { 
        format: "image/jpeg", 
        quality: 95 
      };
      const arrayBuffer = await imagePackerApi.packing(pixelMap, packOpts);
      
      // 调用系统文件选择器保存文件
      await this.saveImageToLocal(arrayBuffer);
      
      console.log('壁纸下载成功');
      promptAction.showToast({
        message: '壁纸下载成功！',
        duration: 2000
      });
      
    } catch (err) {
      console.error('下载壁纸失败:', err);
      let errMsg = '壁纸下载失败，请重试';
      if (err instanceof Error) {
        errMsg = err.message || errMsg;
      }
      promptAction.showToast({
        message: errMsg,
        duration: 2000
      });
    }
  }
  
  /**
   * 使用系统文件选择器保存图片到本地
   * @param arrayBuffer 图片数据
   */
  private async saveImageToLocal(arrayBuffer: ArrayBuffer) {
    // 说明：通过系统文件选择器（PhotoViewPicker.save）进行保存，无需额外的媒体读写权限；
    // 系统会为返回的目标URI授予一次性写入权限。我们只需按URI写入并做好异常处理和资源释放。
    let file: fs.File | null = null;
    try {
      // 创建文件保存选择器
      const photoSaveOptions = new picker.PhotoSaveOptions();
      photoSaveOptions.newFileNames = [`语录壁纸_${Date.now()}.jpg`];

      const photoViewPicker = new picker.PhotoViewPicker();

      // 调用save接口拉起FilePicker界面进行文件保存
      const photoSaveResult = await photoViewPicker.save(photoSaveOptions);

      if (!photoSaveResult || photoSaveResult.length === 0) {
        throw new Error('用户取消了保存操作');
      }

      const saveUri = photoSaveResult[0];
      const totalBytes = arrayBuffer?.byteLength ?? 0;
      console.log(`获取保存路径成功: ${saveUri}, 即将写入字节数: ${totalBytes}`);
      if (!arrayBuffer || totalBytes <= 0) {
        throw new Error('生成的图片数据为空，无法保存');
      }

      // 使用只写模式+创建+清空，兼容平台行为
      const openMode = fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC;
      file = fs.openSync(saveUri, openMode);

      // 将ArrayBuffer转换为Uint8Array以便稳健分块写入
      const u8 = new Uint8Array(arrayBuffer);

      // 优先使用同步写入，确保全部落盘；若不可用则回退到异步写入
      let writtenTotal = 0;
      const writeChunkSize = 256 * 1024; // 256KB分块写入，避免一次性写过大导致失败

      const tryWriteSync = (buf: Uint8Array): number => {
        // 某些版本仅支持ArrayBuffer入参，需切片保证偏移正确
        const arrBuf: ArrayBuffer = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
        return fs.writeSync(file!.fd, arrBuf);
      };

      if (typeof fs.writeSync === 'function') {
        // 分块同步写入
        for (let offset = 0; offset < u8.length; offset += writeChunkSize) {
          const end = Math.min(offset + writeChunkSize, u8.length);
          const chunk = u8.subarray(offset, end);
          const w = tryWriteSync(chunk);
          if (typeof w !== 'number' || w <= 0) {
            throw new Error(`写入失败（同步），offset=${offset}, 返回=${String(w)}`);
          }
          writtenTotal += w;
        }
      } else {
        // 回退：一次性异步写入
        const w = await fs.write(file.fd, arrayBuffer);
        if (typeof w !== 'number' || w <= 0) {
          throw new Error(`写入失败（异步），返回=${String(w)}`);
        }
        writtenTotal = w;
      }

      if (writtenTotal !== totalBytes) {
        console.warn(`写入字节与期望不一致: 期望=${totalBytes}, 实际=${writtenTotal}`);
      } else {
        console.log(`图片写入完成，总字节=${writtenTotal}`);
      }

      // 去除对 fsAny 和 fsyncSync 的使用，避免 ArkTS any 与“命名空间作为对象”错误
      // 说明：部分平台不提供 fsync 能力；closeSync 前系统会刷新缓冲区，配合分块写入已足以保证稳定性

      console.log('图片保存成功:', saveUri);
    } catch (e) {
      console.error('保存图片失败:', e);
      if (e instanceof Error) {
        throw e; // 向上抛出，统一由调用方提示用户
      } else {
        throw new Error('保存图片失败: ' + String(e));
      }
    } finally {
      // 确保文件句柄被关闭，避免资源泄露
      if (file) {
        try {
          fs.closeSync(file);
        } catch (closeErr) {
          console.warn('关闭文件句柄时发生异常:', closeErr);
        }
      }
    }
  }

  /**
   * 关闭下载遮罩
   */
  private closeDownloadOverlay() {
    this.isDownloadVisible = false;
    this.downloadState = 'confirm';
  }

  /**
   * 确认下载
   */
  private confirmDownload() {
    this.downloadState = 'loading';
    // 执行实际下载
    this.downloadWallpaper().then(() => {
      this.downloadState = 'success';
      // 2秒后自动关闭
      setTimeout(() => {
        this.closeDownloadOverlay();
      }, 2000);
    }).catch(() => {
      this.downloadState = 'confirm';
    });
  }

  /**
   * 构建页面UI
   */
  build() {
    Stack() {
      // 主预览容器
      Stack() {
        // Canvas背景
        // 使用HarmonyOS标准Canvas组件：传递预创建的CanvasRenderingContext2D对象
        Canvas(this.canvasContext)
          .width('100%')
          .height('100%')
          .onReady(() => {
            console.log('Canvas onReady called.');
            
            // 直接使用预创建的canvasContext对象
            this.canvasElement = this.canvasContext;
            console.log('Canvas context ready. Element:', !!this.canvasElement);
            
            // 如果尺寸已知，立即绘制；否则等待onAreaChange
            if (this.canvasWidth > 0 && this.canvasHeight > 0) {
              console.log('Canvas onReady: Context and size ready, drawing initial background.');
              this.drawLayeredWaves(this.currentQuoteColor);
            } else {
              console.log('Canvas onReady: Context ready, waiting for size (onAreaChange) to draw. W:', this.canvasWidth, ', H:', this.canvasHeight);
            }
          })
          .onAreaChange((oldValue: Area, newValue: Area) => {
            const newWidth = Number(newValue.width);
            const newHeight = Number(newValue.height);
            console.log(`Canvas尺寸变化: ${this.canvasWidth}x${this.canvasHeight} -> ${newWidth}x${newHeight}`);
            this.canvasWidth = newWidth;
            this.canvasHeight = newHeight;

            // 确保Canvas元素已就绪
            if (!this.canvasElement) {
              this.canvasElement = this.canvasContext;
              console.log('Canvas onAreaChange: Canvas元素已就绪. Element:', !!this.canvasElement);
            }
            
            // 尺寸变化后，如果Canvas上下文已就绪且尺寸有效，则重新绘制
            if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
              setTimeout(() => {
                console.log('Canvas尺寸已更新，开始绘制波浪背景，使用颜色:', this.currentQuoteColor);
                this.drawLayeredWaves(this.currentQuoteColor);
              }, 50); // 减少延迟，提高响应速度
            } else {
              console.log('Canvas onAreaChange: 等待Canvas上下文就绪. Element:', !!this.canvasElement, ', Context:', !!this.canvasContext, ', W:', this.canvasWidth, ', H:', this.canvasHeight);
            }
          })

        // 语录内容区域已移至Canvas绘制，此处不再需要UI层Text组件

        // 返回按钮
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .borderRadius(20)
        .position({ x: 16, y: 48 })
        .onClick(() => this.goBack())

        // 导航提示
        if (this.quotes.length > 1) {
          Row() {
            ForEach(this.quotes, (quote: Quote, index: number) => {
              Circle()
                .width(8)
                .height(8)
                .fill(index === this.currentQuoteIndex ? '#FFFFFF' : 'rgba(255, 255, 255, 0.4)')
                .margin({ left: 4, right: 4 })
            })
          }
          .position({ x: '50%', y: '85%' })
          .translate({ x: '-50%', y: 0 })
        }

        // 底部操作栏
        if (this.isControlsVisible) {
          Row() {
            // 设置壁纸按钮
            Button() {
              Column() {
                Image($r('app.media.ic_wallpaper'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('设置壁纸')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.setWallpaper()) // 确保此 onClick 有效
            Blank()
            // 编辑按钮
            Button() {
              Column() {
                Image($r('app.media.ic_edit'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('编辑语录')
                  .fontSize(12)
                  .fontColor('#ffffff')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('#4A90E2')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.editQuote()) // 确保此 onClick 有效
            Blank()
            // 分享按钮
            Button() {
              Column() {
                Image($r('app.media.ic_share'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('下载壁纸')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.downloadWallpaper()) // 确保此 onClick 有效
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 32 })
          .position({ x: 0, y: '100%' })
          .translate({ x: 0, y: '-100%' })
        }

        // 下载生成遮罩
        if (this.isDownloadVisible) {
          Column() {
            // 遮罩背景
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => this.closeDownloadOverlay())
            // 下载内容卡片
            Column() {
              Text('下载壁纸')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ bottom: 16 })
              // 预览内容
              Column() {
                Text(this.quotes[this.currentQuoteIndex]?.text || '')
                  .fontSize(16)
                  .fontColor('#333333')
                  .textAlign(TextAlign.Center)
                  .lineHeight(24)
                // .maxLines(4) // 可选：如果希望下载预览也限制行数
                // .textOverflow({ overflow: TextOverflow.Ellipsis }) // 可选
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F8F9FA')
              .borderRadius(8)
              .margin({ bottom: 20 })
              // 状态显示
              if (this.downloadState === 'loading') {
                Column() {
                  LoadingProgress()
                    .width(32)
                    .height(32)
                    .color('#007AFF')
                  Text('正在生成下载图片...')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 8 })
                }
                .margin({ bottom: 20 })
              } else if (this.downloadState === 'success') {
                Column() {
                  Text('✅')
                    .fontSize(32)
                  Text('下载成功！')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 8 })
                }
                .margin({ bottom: 20 })
              }
              // 操作按钮
              Row() {
                Button('取消')
                  .width(80)
                  .height(40)
                  .fontSize(16)
                  .fontColor('#666666')
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .onClick(() => this.closeDownloadOverlay())
                Blank()
                Button(this.downloadState === 'loading' ? '下载中...' :
                  this.downloadState === 'success' ? '完成' : '下载')
                  .width(120)
                  .height(40)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.downloadState === 'loading' ? '#CCCCCC' : '#007AFF')
                  .borderRadius(8)
                  .enabled(this.downloadState !== 'loading')
                  .onClick(() => {
                    if (this.downloadState === 'success') {
                      this.closeDownloadOverlay();
                    } else {
                      this.confirmDownload();
                    }
                  })
              }
              .width('100%')
            }
            .width('80%')
            .padding(24)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .position({ x: '50%', y: '50%' })
            .translate({ x: '-50%', y: '-50%' })
          }
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
        }

        // 加载状态
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color('#FFFFFF')
            Text('加载中...')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .margin({ top: 16 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.8)')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .gesture(
        // 添加触摸手势
        PanGesture()
          .onActionStart((event) => {
            this.touchStartX = event.fingerList[0].globalX;
            this.touchStartY = event.fingerList[0].globalY;
          })
          .onActionEnd((event) => {
            const touchEndX = event.fingerList[0].globalX;
            const touchEndY = event.fingerList[0].globalY;
            const deltaX = touchEndX - this.touchStartX;
            const deltaY = touchEndY - this.touchStartY;
            // 判断是否为水平滑动
            if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
              if (deltaX > 0) {
                // 向右滑动 - 上一条
                this.previousQuote();
              } else {
                // 向左滑动 - 下一条
                this.nextQuote();
              }
            }
          })
      )
      .onClick(() => {
        this.toggleControls();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000') // 保持黑色背景
  }

  /**
   * 将RGBA字节数组转换为BGRA顺序
   * - 目的：HarmonyOS在createPixelMap时常使用BGRA_8888格式，这里做通道转换以确保颜色正确
   * @param rgbaData 源RGBA像素数据（Uint8ClampedArray）
   * @returns 转换后的BGRA字节缓冲区（ArrayBuffer）
   */
  private convertRgbaToBgra(rgbaData: Uint8ClampedArray): ArrayBuffer {
    const len = rgbaData.length;
    const out = new Uint8Array(len);
    for (let i = 0; i < len; i += 4) {
      out[i] = rgbaData[i + 2];     // B
      out[i + 1] = rgbaData[i + 1]; // G
      out[i + 2] = rgbaData[i];     // R
      out[i + 3] = rgbaData[i + 3]; // A
    }
    return out.buffer;
  }
}