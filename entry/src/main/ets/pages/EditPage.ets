import { promptAction, router, font } from '@kit.ArkUI';
import { QuoteDataManager, Quote, AddQuoteParams, UpdateQuoteParams } from '../common/QuoteDataManager';

// 添加颜色候选数组，与 WallpaperPage 的 WALLPAPER_COLORS 保持一致
const WALLPAPER_COLORS: string[] = [
  "#E57373", "#F06292", "#BA68C8", "#9575CD", "#7986CB",
  "#64B5F6", "#4DB6AC", "#81C784", "#DCE775", "#FFD54F",
  "#5488BC", "#917C6B", "#AA9F7C", "#A29296", "#515E68"
];

/**
 * 编辑页面参数接口
 * 修复：quote 应该是序列化后的字符串，而不是 Quote 对象
 */
interface EditPageParams {
  mode?: string; // 'add' 或 'edit'
  quote?: string; // 修复：编辑模式下传递的语录对象 JSON 字符串
}

/**
 * Toast选项接口
 */
interface ShowToastOptions {
  message: string;
  duration?: number;
}

/**
 * 文字样式接口
 */
interface TextStyle {
  fontSize: number;
  lineHeight: number;
}

/**
 * 编辑页面组件
 * 基于edit.html实现语录编辑、预览、Canvas绘制等功能
 */
@Entry
@Component
struct EditPage {
  @State isEditMode: boolean = false;
  @State editingQuote: Quote | null = null;
  @State quoteContent: string = '';
  @State charCount: number = 0;
  @State maxLength: number = 200;
  @State isLoading: boolean = false;
  @State quotes: Quote[] = [];
  private dataManager: QuoteDataManager = QuoteDataManager.getInstance(getContext(this));
  
  // Canvas相关状态 - 与WallpaperPage保持一致
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;
  private canvasElement: CanvasRenderingContext2D | null = null;
  @State currentQuoteColor: string = '#4A90E2'; // 默认颜色，与WallpaperPage一致

  /**
   * 页面即将出现时的初始化
   */
  async aboutToAppear() {
    // 注册自定义字体
    font.registerFont({
      familyName: 'SimHei',
      familySrc: $rawfile('simhei.ttf')
    });
    await this.initPage();
  }

    /**
   * 页面初始化（异步）
   * 解析URL参数决定是否为编辑模式，编辑模式下加载本地语录用于回填
   * 修复：正确处理从 Index 传递的 JSON 字符串参数
   */
  async initPage() {
    try {
      // 检查是否为编辑模式（通过路由参数）
      // 获取路由参数，根据修正后的 EditPageParams 接口，quote 是 string 类型
      const params = router.getParams() as EditPageParams | undefined;

      // 检查 params 是否存在且为对象（router.getParams 通常返回对象或 undefined）
      if (params) {
        // 现在可以安全地访问 params.mode 和 params.quote (因为接口定义已修正)
        if (params.mode === 'edit' && params.quote) {
          this.isEditMode = true;
          try {
            // 关键修复：将接收到的 JSON 字符串解析回 Quote 对象
            const parsedQuote: Quote = JSON.parse(params.quote);
            console.log('Parsed Quote for editing:', parsedQuote); // 调试用
            this.editingQuote = parsedQuote; // 正确赋值解析后的对象
            // 回填编辑数据
            // 关键修复：确保 parsedQuote.text 存在，否则使用空字符串
            this.quoteContent = parsedQuote.text ?? '';
            this.charCount = this.quoteContent.length;
          } catch (parseError) {
             console.error('解析传递的 quote 参数失败:', parseError, params.quote);
             // 解析失败时，可以设置为默认状态或显示错误
             this.isEditMode = false; // 回退到新增模式或显示错误提示
             this.showToast('数据加载失败');
             // 可选：返回上一页
             // router.back();
          }
        }
        // 如果是新增模式 (params.mode !== 'edit' 或 params.quote 不存在)，则保持默认状态 (isEditMode = false, quoteContent = '')
      }
      // 即使在编辑模式下，validateForm 也应该在 quoteContent 设置后调用
      this.validateForm();
    } catch (error) {
      console.error('页面初始化失败:', error);
      // 可选：显示通用错误提示
      this.showToast('页面初始化失败');
    }
  }

  /**
   * 加载语录数据（用于编辑页回填）
   */
  async loadQuotesForEdit(): Promise<void> {
    try {
      await this.dataManager.initialize();
      this.quotes = await this.dataManager.getAllQuotes();
    } catch (error) {
      console.error('从preferences加载语录失败:', error);
    }
  }

  /**
   * 加载编辑数据（在编辑模式下根据id回填内容）
   */
  async loadEditData() {
    if (this.isEditMode && this.editingQuote !== null) {
      try {
        const quote = this.editingQuote;
        if (quote) {
          this.quoteContent = quote.text;
          this.updateCharCount();
        }
      } catch (error) {
        console.error('加载编辑数据失败:', error);
      }
    }
  }

  /**
   * 表单验证
   */
  validateForm(): boolean {
    const content = this.quoteContent.trim();
    return content.length > 0;
  }

  /**
   * 更新字符计数
   */
  updateCharCount() {
    this.charCount = this.quoteContent.length;
  }

  /**
   * 十六进制颜色转RGB（与WallpaperPage保持一致）
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
   * 调整颜色亮度（与WallpaperPage的adjustColor函数保持一致）
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
   * 根据当前语录内容更新颜色（与WallpaperPage保持一致）
   */
  private updateCurrentQuoteColor() {
    // 使用语录内容的长度来选择颜色，确保一致性
    const colorIndex = this.quoteContent.length % WALLPAPER_COLORS.length;
    this.currentQuoteColor = WALLPAPER_COLORS[colorIndex];
    console.log(`当前语录长度: ${this.quoteContent.length}, 使用颜色: ${this.currentQuoteColor}`);
  }

  /**
   * 绘制分层波浪背景（与WallpaperPage的drawLayeredWaves函数100%保持一致）
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
    // 关键修改：先填充背景色 #E6E6E6，与WallpaperPage一致
    ctx.fillStyle = '#E6E6E6';
    ctx.fillRect(0, 0, width, height);

    // 参数设置（与WallpaperPage保持一致）
    const numLayers = 6;
    const baseFromBottom = Math.floor(height * 0.32);
    const gapPerLayer = Math.floor(height * 0.035);
    const baseWavelength = 420;
    const baseAmplitude = 52;
    const step = 6;

    // 绘制6层波浪（从上到下，颜色逐渐加深）
    for (let i = 0; i < numLayers; i++) {
      // 颜色调整（与WallpaperPage的adjust_color逻辑一致）
      const colorFactor = 1 - i * 0.06;
      const adjustedRgb = this.adjustColor(baseRgb, colorFactor);
      // 透明度计算（与WallpaperPage一致：25 + i*38，转换为0-1范围）
      const alpha = Math.min(255, 25 + i * 38) / 255;
      ctx.fillStyle = `rgba(${adjustedRgb[0]}, ${adjustedRgb[1]}, ${adjustedRgb[2]}, ${alpha})`;

      // 波浪参数（与WallpaperPage一致）
      const wavelength = baseWavelength * (1.0 + i * 0.03);
      const amplitude = baseAmplitude * (1.0 + i * 0.05);
      const phase = Math.random() * Math.PI * 2; // 随机相位

      // 层偏移计算（与WallpaperPage一致）
      const layerOffset = height - (baseFromBottom - i * gapPerLayer);

      // 创建波浪路径
      ctx.beginPath();
      // 绘制正弦波（与WallpaperPage逻辑一致）
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

      // 封闭路径到底部（与WallpaperPage一致）
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
    }
    console.log('Canvas drawing completed successfully.');
  }

  /**
   * 初始化壁纸预览Canvas（与WallpaperPage保持一致）
   */
  private initWallpaperPreview(ctx: CanvasRenderingContext2D) {
    this.canvasElement = ctx;
    console.log('Canvas element ready. Element:', !!this.canvasElement);
    
    // 如果尺寸已知，立即绘制；否则等待onAreaChange
    if (this.canvasWidth > 0 && this.canvasHeight > 0) {
      console.log('Canvas ready: Context and size ready, drawing initial background.');
      this.updateCurrentQuoteColor();
      this.drawLayeredWaves(this.currentQuoteColor);
    } else {
      console.log('Canvas ready: Context ready, waiting for size (onAreaChange) to draw. W:', this.canvasWidth, ', H:', this.canvasHeight);
    }
  }

  /**
   * 更新壁纸预览（与WallpaperPage保持一致）
   */
  private updateWallpaperPreview() {
    if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
      // 根据当前语录内容更新颜色
      this.updateCurrentQuoteColor();
      // 重新绘制背景
      this.drawLayeredWaves(this.currentQuoteColor);
    } else {
      console.log('Canvas not ready for update. Element:', !!this.canvasElement, ', W:', this.canvasWidth, ', H:', this.canvasHeight);
    }
  }

  /**
   * 返回上一页
   */
  goBack() {
    console.log('返回主界面');
    router.back();
  }

  /**
   * 保存语录
   */
  async saveQuote() {
    const content = this.quoteContent.trim();
    
    if (!content) {
      this.showToast('请输入语录内容');
      return;
    }
    
    if (content.length > this.maxLength) {
      this.showToast(`语录内容不能超过${this.maxLength}字`);
      return;
    }
    
    try {
      this.isLoading = true;
      
      if (this.isEditMode && this.editingQuote !== null) {
        // 编辑模式：更新现有语录
        const updateParams: UpdateQuoteParams = {
          text: content,
          updatedAt: new Date().toISOString()
        };
        
        const updatedQuote = await this.dataManager.updateQuote(this.editingQuote.id, updateParams);
        if (updatedQuote) {
          this.showToast('语录更新成功！');
        } else {
          this.showToast('语录更新失败，未找到对应记录');
          return;
        }
      } else {
        // 新增模式：添加新语录
        const addParams: AddQuoteParams = {
          text: content,
          tags: []
        };
        
        await this.dataManager.addQuote(addParams);
        this.showToast('语录保存成功！');
      }
      
      // 保存成功后返回主页
      setTimeout(() => {
        router.back();
      }, 600);
    } catch (error) {
      console.error('保存失败:', error);
      this.showToast('保存失败，请重试');
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 显示提示消息
   */
  showToast(message: string) {
    const toast: ShowToastOptions = {
      message: message,
      duration: 3000
    };
    promptAction.showToast(toast);
  }

  /**
   * 根据字数自动调整文字样式（与WallpaperPage 100%保持一致）
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

  build() {
    Column() {
      // 导航栏
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor('#007AFF')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.goBack())
        
        Text(this.isEditMode ? '编辑语录' : '新增语录')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Button(this.isLoading ? '保存中...' : '保存')
          .fontSize(16)
          .backgroundColor(this.isLoading ? '#CCCCCC' : '#007AFF')
          .fontColor(Color.White)
          .borderRadius(6)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .enabled(!this.isLoading)
          .onClick(() => this.saveQuote())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })

      Scroll() {
        Column({ space: 20 }) {
          // 表单容器
          Column({ space: 16 }) {
            // 语录内容
            Column({ space: 12 }) {
              Row() {
                Text('语录内容')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                
                Text('*')
                  .fontSize(16)
                  .fontColor('#FF3B30')
              }
              .alignItems(VerticalAlign.Center)
              
              TextArea({
                placeholder: '请输入语录内容，让文字传递力量...',
                text: this.quoteContent
              })
                .width('100%')
                .height(120)
                .fontSize(16)
                .backgroundColor('#F8F9FA')
                .borderRadius(8)
                .padding(16)
                .border({ width: 1, color: '#E5E5E5' })
                .onChange((value: string) => {
                  this.quoteContent = value;
                  this.updateCharCount();
                  this.validateForm();
                  // 延迟更新预览，避免频繁重绘
                  setTimeout(() => {
                    this.updateWallpaperPreview();
                  }, 100);
                })
              
              Row() {
                Text(`${this.charCount}/${this.maxLength}`)
                  .fontSize(12)
                  .fontColor(this.charCount > this.maxLength * 0.9 ? (this.charCount >= this.maxLength ? '#FF3B30' : '#FF9500') : '#999999')
              }
              .width('100%')
              .justifyContent(FlexAlign.End)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetX: 0, offsetY: 2 })

          // 壁纸预览容器
          Column({ space: 16 }) {
            Row() {
              Image($r('app.media.ic_preview'))
                .width(16)
                .height(16)
                .fillColor('#666666')
              
              Text('壁纸预览')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
            }
            .alignItems(VerticalAlign.Center)
            
            // 预览区域
            Stack() {
              // Canvas背景 - 与WallpaperPage保持一致
              Canvas(this.canvasContext)
                .width('100%')
                .aspectRatio(9/16) // 竖向手机屏幕比例
                .borderRadius(12)
                .onReady(() => {
                  console.log('Canvas ready for wallpaper preview');
                  // Canvas准备就绪时初始化
                  if (this.canvasContext) {
                    this.initWallpaperPreview(this.canvasContext);
                  }
                })
                .onAreaChange((oldValue: Area, newValue: Area) => {
                  // 当Canvas尺寸改变时更新尺寸并重绘
                  const newWidth = Number(newValue.width);
                  const newHeight = Number(newValue.height);
                  
                  if (newWidth !== this.canvasWidth || newHeight !== this.canvasHeight) {
                    this.canvasWidth = newWidth;
                    this.canvasHeight = newHeight;
                    console.log(`Canvas size changed: ${this.canvasWidth}x${this.canvasHeight}`);
                    
                    // 延迟重绘，确保Canvas尺寸更新完成
                    setTimeout(() => {
                      this.updateWallpaperPreview();
                    }, 100);
                  }
                })
              
              // 文字覆盖层 - 与WallpaperPage完全保持一致
              Column() {
                Text(this.quoteContent || '请输入语录内容...')
                  .fontSize(this.getTextStyle(this.quoteContent || '').fontSize)
                  .fontColor('#181818')
                  .textAlign(TextAlign.Center)
                  .lineHeight(this.getTextStyle(this.quoteContent || '').lineHeight)
                  .fontWeight(FontWeight.Medium)
                  .padding({ left: 32, right: 32 })
                  .decoration({ type: TextDecorationType.None })
                  .fontFamily('SimHei') // 使用注册的字体名称
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .position({ x: 0, y: '15%' }) // 与WallpaperPage一致的文字位置
            }
            .width('100%')
            .alignContent(Alignment.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetX: 0, offsetY: 2 })
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}