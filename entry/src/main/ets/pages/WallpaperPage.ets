import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { font } from '@kit.ArkUI';
import { QuoteDataManager, Quote } from '../common/QuoteDataManager';
import wallpaper from '@ohos.wallpaper'; // 导入壁纸设置API
import image from '@ohos.multimedia.image'; // 导入图像处理API
import display from '@ohos.display'; // 获取屏幕尺寸用于回退
import photoAccessHelper from '@ohos.file.photoAccessHelper'; // 导入相册访问API
import fs from '@ohos.file.fs';
// SaveButton是安全控件，直接使用，无需导入
import { common } from '@kit.AbilityKit'; // 导入应用上下文
import { Want } from '@kit.AbilityKit'; // 导入Want接口用于分享功能

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
  @State isShareVisible: boolean = false;
  @State shareState: 'confirm' | 'loading' | 'success' = 'confirm';
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
    // 注册自定义字体
    font.registerFont({
      familyName: 'SimHei',
      familySrc: $rawfile('fangzheng.ttf')
    });
    await this.loadQuotes();
    this.initializeIndex();
  }

  /**
   * 页面显示时的回调
   * 用于处理从编辑页面返回时的数据刷新
   */
  async onPageShow() {
    console.log('WallpaperPage: 页面显示，检查是否需要刷新数据');
    
    // 重新加载语录数据，以获取最新的编辑结果
    const previousQuotesLength = this.quotes.length;
    const currentQuoteId = this.quotes[this.currentQuoteIndex]?.id;
    
    await this.loadQuotes();
    
    // 如果当前语录ID存在，尝试找到更新后的位置
    if (currentQuoteId && this.quotes.length > 0) {
      const updatedIndex = this.quotes.findIndex(q => q.id === currentQuoteId);
      if (updatedIndex >= 0) {
        // 找到了对应的语录，更新索引
        this.currentQuoteIndex = updatedIndex;
        console.log(`WallpaperPage: 找到更新后的语录，索引为: ${updatedIndex}`);
      } else {
        // 没找到对应语录（可能被删除），重置到第一条
        this.currentQuoteIndex = 0;
        console.log('WallpaperPage: 原语录未找到，重置到第一条');
      }
    } else if (this.quotes.length > 0) {
      // 确保索引在有效范围内
      this.currentQuoteIndex = Math.min(this.currentQuoteIndex, this.quotes.length - 1);
    }
    
    // 更新当前语录的颜色
    this.updateCurrentQuoteColor();
    
    // 重新绘制背景
    setTimeout(() => {
      if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
        this.drawLayeredWaves(this.currentQuoteColor);
        console.log('WallpaperPage: 页面返回后重新绘制背景完成');
      }
    }, 100);
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
   */
  private drawLayeredWaves(baseColor: string) {
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
    // 关键修改：先填充背景色 #E6E6E6，与web版本一致
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
    console.log('Canvas drawing completed successfully.');
  }

  /**
   * 根据字数自动调整文字样式 (更接近web版本)
   * 修复：返回正确的行高数值，避免文字重叠
   */
  private getTextStyle(content: string): TextStyle {
    const length = content.length;
    if (length <= 15) {
      // 增大字体，调整行高，更符合web效果
      return { fontSize: 28, lineHeight: 39 }; // 28 * 1.4 = 39.2
    } else if (length <= 30) {
      return { fontSize: 24, lineHeight: 36 }; // 24 * 1.5 = 36
    } else if (length <= 50) {
      return { fontSize: 20, lineHeight: 32 }; // 20 * 1.6 = 32
    } else {
      // 对于长文本，进一步减小字体和增加行高
      return { fontSize: 18, lineHeight: 31 }; // 18 * 1.7 = 30.6
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
   * 下载壁纸 - 将生成的壁纸保存到相册
   */
  private async setWallpaper() {
    try {
      console.log('开始下载壁纸:', this.quotes[this.currentQuoteIndex]);
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
        console.error('Canvas上下文未就绪，无法导出图像数据 (在下载壁纸中)');
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
      
      // 保存壁纸到相册
      await this.saveImageToAlbum(pixelMap);
      
      console.log('壁纸下载成功');
      promptAction.showToast({
        message: '壁纸已保存到相册！',
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
   * 等待Canvas就绪，确保已获取上下文且尺寸有效；如尺寸无效则回退为屏幕分辨率
   * @param timeoutMs 最大等待时长
   * @returns 是否就绪
   */
  private async ensureCanvasReady(timeoutMs: number = 1000): Promise<boolean> {
    const start = Date.now();
    // 若还未初始化上下文，尝试从 this.canvasContext (@State) 获取
    // 主要逻辑依赖 onReady 和 onAreaChange，这里作为后备和等待
    while ((!this.canvasElement || this.canvasWidth <= 0 || this.canvasHeight <= 0) && Date.now() - start < timeoutMs) {
      // 修复：在等待期间也尝试从 canvasContext 获取
      // 处理框架赋值可能存在的极短延迟
      if (!this.canvasElement && this.canvasContext) {
        this.canvasElement = this.canvasContext; // 类型兼容
        console.log('ensureCanvasReady: Assigned canvasElement from canvasContext during wait loop.');
      }
      // 如果尺寸为0但上下文有效，尝试获取屏幕尺寸
      if ((this.canvasWidth <= 0 || this.canvasHeight <= 0) && this.canvasElement) {
        try {
          const d = await display.getDefaultDisplay();
          this.canvasWidth = d.width;
          this.canvasHeight = d.height;
          console.log(`Canvas尺寸回退为屏幕尺寸: ${this.canvasWidth}x${this.canvasHeight}`);
          // 尺寸变更后重新绘制
          if (this.canvasElement) {
            this.drawLayeredWaves(this.currentQuoteColor);
          }
        } catch (e) {
          console.warn('获取屏幕尺寸失败，保持原尺寸。');
        }
      }
      // 如果仍未就绪，等待一小段时间再检查
      if (!this.canvasElement || this.canvasWidth <= 0 || this.canvasHeight <= 0) {
        await new Promise<void>((resolve) => setTimeout(resolve, 50));
      }
    }
    // 最终检查
    const isReady = !!this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0;
    console.log(`Canvas就绪检查最终结果: ${isReady}. Element: ${!!this.canvasElement}, Width: ${this.canvasWidth}, Height: ${this.canvasHeight}`);
    return isReady;
  }

  /**
   * 将ImageData转换为PixelMap
   */
  private async createPixelMapFromImageData(imageData: ImageData): Promise<image.PixelMap> {
    try {
      // 创建PixelMap的配置
      const opts: image.InitializationOptions = {
        alphaType: 0, // UNKNOWN
        editable: true,
        pixelFormat: 3, // RGBA_8888
        scaleMode: 1, // CENTER_CROP
        size: {
          height: this.canvasHeight,
          width: this.canvasWidth
        }
      };
      // 从ImageData创建PixelMap
      // 修复：确保传递的是 ArrayBuffer
      const pixelMap = await image.createPixelMap(imageData.data.buffer.slice(0) as ArrayBuffer, opts);
      return pixelMap;
    } catch (err) {
      console.error('创建PixelMap失败:', err);
      // 提供更具体的错误信息
      let errMsg = '创建壁纸数据失败';
      if (err instanceof Error) {
        errMsg = err.message || errMsg;
      }
      throw new Error(errMsg);
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
   * 分享壁纸
   */
  private shareWallpaper() {
    this.callSystemShare();
  }

  /**
   * 关闭分享遮罩
   */
  private closeShareOverlay() {
    this.isShareVisible = false;
    this.shareState = 'confirm';
  }

  /**
   * 确认分享
   */
  private confirmShare() {
    this.shareState = 'loading';
    // 模拟生成过程
    setTimeout(() => {
      this.shareState = 'success';
    }, 2000);
  }

  /**
   * 调用系统分享
   * 使用Want和startAbility调用系统分享面板
   */
  private async callSystemShare() {
    try {
      console.log('调用系统分享面板');
      
      // 获取当前语录内容
      const currentQuote = this.quotes[this.currentQuoteIndex];
      const shareText = currentQuote ? currentQuote.text : '分享一句美好的语录';
      
      // 构建Want对象用于分享
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'text/plain',
        parameters: {
          'ohos.extra.param.key.TEXT': shareText
        }
      };
      
      // 获取应用上下文
      const context = getContext(this) as common.UIAbilityContext;
      
      // 调用系统分享面板
      await context.startAbility(want);
      
      console.log('系统分享面板调用成功');
      promptAction.showToast({
        message: '正在打开分享面板...',
        duration: 2000
      });
      
    } catch (error) {
      console.error('调用系统分享面板失败:', error);
      promptAction.showToast({
        message: '分享功能暂时不可用',
        duration: 2000
      });
    } finally {
      // 关闭分享遮罩
      this.closeShareOverlay();
    }
  }

  /**
   * 保存图片到相册
   * 使用SaveButton组件提供的临时权限保存图片到相册
   */
  private async saveImageToAlbum(pixelMap: image.PixelMap): Promise<void> {
    try {
      // 获取应用上下文
      const context = getContext(this) as common.UIAbilityContext;
      
      // 创建photoAccessHelper实例
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      
      // 生成符合规范的文件名：包含有效文件主名和扩展名，长度1-255字符
      const timestamp = new Date().getTime();
      const fileName = `wallpaper_${timestamp}.jpg`;
      
      // 将PixelMap转换为ArrayBuffer
      const imagePackerApi = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 90
      };
      const arrayBuffer = await imagePackerApi.packing(pixelMap, packOpts);
      
      // 使用SaveButton提供的临时权限创建资产
      // 在点击SaveButton后10秒内通过createAsset接口创建图片文件
      const uri = await phAccessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      
      // 打开文件并写入数据
      const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      try {
        await fs.write(file.fd, arrayBuffer);
      } finally {
        await fs.close(file.fd);
      }
      
      console.log('图片已成功保存到相册:', fileName);
      promptAction.showToast({
        message: '壁纸已保存到相册',
        duration: 2000
      });
    } catch (error) {
      console.error('保存图片到相册失败:', error);
      promptAction.showToast({
        message: '保存失败，请重试',
        duration: 2000
      });
      throw new Error('保存图片失败，请重试');
    }
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

        // 语录内容区域 (修复文字重叠和位置问题)
        if (!this.isLoading && this.quotes.length > 0) {
          Column() {
            Text(this.quotes[this.currentQuoteIndex]?.text || '')
              .fontSize(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').fontSize)
              .fontColor('#181818')
              .textAlign(TextAlign.Center)
              .lineHeight(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').lineHeight)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 32, right: 32 })
              // 移除了 shadow 属性
              .decoration({ type: TextDecorationType.None })
              .fontFamily('SimHei') // 使用注册的字体名称
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .position({ x: 0, y: '25%' }) // 修复：将文字位置向上调整，从45%改为35%
        }

        // 返回按钮
        Button() {
          Text('←')
            .fontSize(24)
            .fontColor('#FFFFFF')
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
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.editQuote()) // 确保此 onClick 有效
            Blank()
            // 保存壁纸按钮 - 使用SaveButton安全控件获取临时权限
            SaveButton()
            .width(72)
            .height(72)
            .backgroundColor('#4A90E2')
            .borderRadius(36)
            .padding(12)
            .onClick((event: ClickEvent, result: number) => {
              if (result === 0) { // 0表示SUCCESS
                // SaveButton点击成功，获得10秒临时权限，立即执行保存
                this.setWallpaper();
              } else {
                console.error('SaveButton点击失败:', result);
                promptAction.showToast({
                  message: '保存权限获取失败，请重试',
                  duration: 2000
                });
              }
            })
            Blank()
            // 分享按钮
            Button() {
              Column() {
                Image($r('app.media.ic_share'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('分享壁纸')
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
            .onClick(() => this.shareWallpaper()) // 确保此 onClick 有效
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 32 })
          .position({ x: 0, y: '100%' })
          .translate({ x: 0, y: '-100%' })
        }

        // 分享生成遮罩
        if (this.isShareVisible) {
          Column() {
            // 遮罩背景
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => this.closeShareOverlay())
            // 分享内容卡片
            Column() {
              Text('分享壁纸')
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
                // .maxLines(4) // 可选：如果希望分享预览也限制行数
                // .textOverflow({ overflow: TextOverflow.Ellipsis }) // 可选
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F8F9FA')
              .borderRadius(8)
              .margin({ bottom: 20 })
              // 状态显示
              if (this.shareState === 'loading') {
                Column() {
                  LoadingProgress()
                    .width(32)
                    .height(32)
                    .color('#007AFF')
                  Text('正在生成分享图片...')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 8 })
                }
                .margin({ bottom: 20 })
              } else if (this.shareState === 'success') {
                Column() {
                  Text('✅')
                    .fontSize(32)
                  Text('生成成功！')
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
                  .onClick(() => this.closeShareOverlay())
                Blank()
                Button(this.shareState === 'loading' ? '生成中...' :
                  this.shareState === 'success' ? '调用分享' : '分享')
                  .width(120)
                  .height(40)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.shareState === 'loading' ? '#CCCCCC' : '#007AFF')
                  .borderRadius(8)
                  .enabled(this.shareState !== 'loading')
                  .onClick(() => {
                    if (this.shareState === 'success') {
                      this.callSystemShare();
                    } else {
                      this.confirmShare();
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
}