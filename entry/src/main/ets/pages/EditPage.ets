import { promptAction, router } from '@kit.ArkUI';
import { QuoteDataManager, Quote, AddQuoteParams, UpdateQuoteParams } from '../common/QuoteDataManager';

/**
 * 编辑页面参数接口
 */
interface EditPageParams {
  mode?: string; // 'add' 或 'edit'
  id?: number;   // 编辑模式下的语录ID
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
  @State editingQuoteId: number | null = null;
  @State quoteContent: string = '';
  @State charCount: number = 0;
  @State maxLength: number = 200;
  @State isLoading: boolean = false;
  @State quotes: Quote[] = [];
  private dataManager: QuoteDataManager = QuoteDataManager.getInstance(getContext(this));
  
  // Canvas相关状态
  @State canvasWidth: number = 180;
  @State canvasHeight: number = 320;
  private canvasContext: CanvasRenderingContext2D | null = null;
  private fixedPreviewColor: string = '#3498DB';
  
  // 颜色候选（与main.py保持一致）
  private colors: string[] = [
    '#3498DB', '#E74C3C', '#2ECC71', '#F39C12', '#9B59B6',
    '#1ABC9C', '#E67E22', '#34495E', '#16A085', '#27AE60',
    '#2980B9', '#8E44AD', '#2C3E50', '#F1C40F', '#E91E63',
    '#9C27B0', '#673AB7', '#3F51B5', '#2196F3', '#03DAC6'
  ];

  /**
   * 页面即将出现时的初始化
   */
  async aboutToAppear() {
    await this.initPage();
  }

  /**
   * 页面初始化（异步）
   * 解析URL参数决定是否为编辑模式，编辑模式下加载本地语录用于回填
   */
  async initPage() {
    try {
      // 检查是否为编辑模式（通过路由参数）
      const params = router.getParams() as EditPageParams;
      if (params) {
        const mode = params.mode;
        const quoteId = params.id;
        
        if (mode === 'edit' && quoteId !== null && quoteId !== undefined) {
          this.isEditMode = true;
          this.editingQuoteId = Number(quoteId);
          // 加载本地语录，供回填使用
          await this.loadQuotesForEdit();
          await this.loadEditData();
        }
      }
      
      this.validateForm();
    } catch (error) {
      console.error('页面初始化失败:', error);
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
    if (this.isEditMode && this.editingQuoteId !== null) {
      try {
        const quote = await this.dataManager.getQuoteById(this.editingQuoteId.toString());
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
   * 十六进制颜色转RGB
   */
  hexToRgb(hex: string): number[] {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [
      parseInt(result[1], 16),
      parseInt(result[2], 16),
      parseInt(result[3], 16)
    ] : [0, 0, 0];
  }

  /**
   * 调整颜色亮度（与main.py的adjust_color函数保持一致）
   */
  adjustColor(rgb: number[], factor: number = 1.0): number[] {
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
   * 绘制分层波浪背景（与main.py的draw_layered_waves函数保持一致）
   */
  drawLayeredWaves(ctx: CanvasRenderingContext2D, width: number, height: number, baseColor: string = '#4A90E2') {
    const baseRgb = this.hexToRgb(baseColor);
    
    // 清空画布并设置背景色
    ctx.fillStyle = '#E6E6E6';
    ctx.fillRect(0, 0, width, height);
    
    // 参数设置（与main.py保持一致，按比例缩放）
    const scale = Math.min(width / 375, height / 812); // 相对于手机屏幕的缩放比例
    const numLayers = 6;
    const baseFromBottom = Math.floor(height * 0.32);
    const gapPerLayer = Math.floor(height * 0.035);
    const baseWavelength = 420 * scale;
    const baseAmplitude = 52 * scale;
    const step = Math.max(2, Math.floor(6 * scale));
    
    // 绘制6层波浪（从上到下，颜色逐渐加深）
    for (let i = 0; i < numLayers; i++) {
      // 颜色调整（与main.py的adjust_color逻辑一致）
      const colorFactor = 1 - i * 0.06;
      const adjustedRgb = this.adjustColor(baseRgb, colorFactor);
      
      // 透明度计算（与main.py一致：25 + i*38，转换为0-1范围）
      const alpha = Math.min(255, 25 + i * 38) / 255;
      
      ctx.fillStyle = `rgba(${adjustedRgb[0]}, ${adjustedRgb[1]}, ${adjustedRgb[2]}, ${alpha})`;
      
      // 波浪参数（与main.py一致）
      const wavelength = baseWavelength * (1.0 + i * 0.03);
      const amplitude = baseAmplitude * (1.0 + i * 0.05);
      const phase = Math.random() * Math.PI * 2; // 随机相位
      
      // 层偏移计算（与main.py一致）
      const layerOffset = height - (baseFromBottom - i * gapPerLayer);
      
      // 创建波浪路径
      ctx.beginPath();
      
      // 绘制正弦波（与main.py逻辑一致）
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
      
      // 封闭路径到底部（与main.py一致）
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
    }
  }

  /**
   * 初始化壁纸预览Canvas
   */
  initWallpaperPreview(ctx: CanvasRenderingContext2D) {
    this.canvasContext = ctx;
    // 绘制初始背景（使用固定颜色）
    this.drawLayeredWaves(ctx, this.canvasWidth, this.canvasHeight, this.fixedPreviewColor);
  }

  /**
   * 更新壁纸预览
   */
  updateWallpaperPreview() {
    if (this.canvasContext) {
      // 重新绘制背景（使用固定颜色，不随输入变化）
      this.drawLayeredWaves(this.canvasContext, this.canvasWidth, this.canvasHeight, this.fixedPreviewColor);
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
      
      if (this.isEditMode && this.editingQuoteId !== null) {
        // 编辑模式：更新现有语录
        const updateParams: UpdateQuoteParams = {
          text: content,
          updatedAt: new Date().toISOString()
        };
        
        const updatedQuote = await this.dataManager.updateQuote(this.editingQuoteId.toString(), updateParams);
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
          author: '未知',
          category: '默认',
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
   * 根据字数自动调整文字样式
   */
  getTextStyle(content: string): TextStyle {
    const length = content.length;
    
    if (length <= 15) {
      const style: TextStyle = { fontSize: 16, lineHeight: 1.4 };
      return style;
    } else if (length <= 30) {
      const style: TextStyle = { fontSize: 14, lineHeight: 1.5 };
      return style;
    } else if (length <= 50) {
      const style: TextStyle = { fontSize: 12, lineHeight: 1.6 };
      return style;
    } else {
      const style: TextStyle = { fontSize: 11, lineHeight: 1.7 };
      return style;
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
                  this.updateWallpaperPreview();
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
              // Canvas背景
              Canvas(this.canvasContext)
                .width('100%')
                .aspectRatio(9/16) // 竖向手机屏幕比例
                .borderRadius(12)
                .onReady(() => {
                  if (this.canvasContext) {
                    this.initWallpaperPreview(this.canvasContext);
                  }
                })
              
              // 文字覆盖层
              Column() {
                Text(this.quoteContent || '请输入语录内容...')
                  .fontSize(this.getTextStyle(this.quoteContent).fontSize)
                  .lineHeight(this.getTextStyle(this.quoteContent).lineHeight)
                  .fontColor(Color.White)
                  .textAlign(TextAlign.Center)
                  .fontFamily('SimHei')
                  .textShadow({ radius: 4, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 2 })
                  .maxLines(10)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('90%')
              .justifyContent(FlexAlign.Center)
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