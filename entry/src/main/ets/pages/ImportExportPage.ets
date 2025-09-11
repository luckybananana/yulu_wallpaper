import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { QuoteDataManager, Quote, AddQuoteParams } from '../common/QuoteDataManager';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/**
 * 导入数据接口
 */
interface ImportData {
  quotes?: Quote[];
}

// 添加语录数据接口 - 与QuoteDataManager保持一致

// 对话框按钮接口
interface DialogButton {
  text: string;
  color: string;
}

// Toast选项接口
interface ShowToastOptions {
  message: string;
  duration?: number;
}

// 对话框选项接口 (添加这个接口来匹配 promptAction.showDialog 的参数)
interface ShowDialogOptions {
  title: string;
  message: string;
  buttons: DialogButton[];
  // 可以根据需要添加其他属性，如 alignment, autoCancel 等
}

/**
 * 导入导出页面
 * 基于import-export.html实现数据管理功能
 * 支持语录数据的导入、导出、备份和恢复
 */
@Entry
@Component
struct ImportExportPage {
  // 页面状态
  @State isLoading: boolean = false;
  @State selectedFile: string = '';
  // 服务实例
  private quoteManager = QuoteDataManager.getInstance(getContext(this));

  /**
   * 页面初始化
   */
  async aboutToAppear() {
    // 页面初始化完成
  }

  /**
   * 导出数据到JSON文件
   */
  async exportData() {
    this.isLoading = true;
    try {
      const quotes = await this.quoteManager.getAllQuotes();
      if (quotes.length === 0) {
        const noDataToast: ShowToastOptions = {
          message: '暂无数据可导出',
          duration: 2000
        };
        promptAction.showToast(noDataToast);
        return;
      }
      // 导出为简单字符串数组格式，与quotes.json保持一致
      const exportData: string[] = quotes.map(quote => quote.text);
      const jsonString = JSON.stringify(exportData, null, 2);
      const fileName = `语录备份_${new Date().toISOString().split('T')[0]}.json`;
      // 使用文档保存选择器保存文件
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [fileName];
      documentSaveOptions.fileSuffixChoices = ['.json'];
      const documentViewPicker = new picker.DocumentViewPicker();
      const saveResult = await documentViewPicker.save(documentSaveOptions);
      if (saveResult && saveResult.length > 0) {
        const filePath = saveResult[0];
        // 写入文件内容 - 使用正确的UTF-8编码
        const file = fileIo.openSync(filePath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
        const encoder = util.TextEncoder.create();
        const uint8Array = encoder.encodeInto(jsonString);
        fileIo.writeSync(file.fd, uint8Array.buffer);
        fileIo.closeSync(file.fd);
        const exportSuccessToast: ShowToastOptions = {
          message: `成功导出${quotes.length}条语录\n文件位置: ${filePath}`, // 修复换行符
          duration: 3000
        };
        promptAction.showToast(exportSuccessToast);
      } else {
        const cancelToast: ShowToastOptions = {
          message: '导出已取消',
          duration: 2000
        };
        promptAction.showToast(cancelToast);
      }
    } catch (error) {
      console.error('导出数据失败:', error);
      const exportErrorToast: ShowToastOptions = {
        message: '导出失败，请重试',
        duration: 2000
      };
      promptAction.showToast(exportErrorToast);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 选择导入文件
   */
  async selectImportFile() {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.json', '.txt'];
      const documentViewPicker = new picker.DocumentViewPicker();
      const result = await documentViewPicker.select(documentSelectOptions);
      if (result && result.length > 0) {
        this.selectedFile = result[0];
      }
    } catch (error) {
      console.error('选择文件失败:', error);
      const selectFileErrorToast: ShowToastOptions = {
        message: '选择文件失败',
        duration: 2000 // 修复位置
      };
      promptAction.showToast(selectFileErrorToast);
    }
  }

  // 已删除 shareToWeChat 和 shareToQQ 方法

  /**
   * 确认导入数据
   */
  async confirmImport() {
    if (!this.selectedFile) return;
    this.isLoading = true;
    try {
      const file = fileIo.openSync(this.selectedFile, fileIo.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(1024 * 1024);
      const readLen = fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file.fd);
      // 使用util.TextDecoder正确解码UTF-8文件内容
      const uint8Array = new Uint8Array(buffer, 0, readLen);
      const decoder = util.TextDecoder.create('utf-8');
      const content = decoder.decodeWithStream(uint8Array, { stream: false });
      const jsonData: string[] | ImportData = JSON.parse(content);
      let quotes: Quote[] = [];
      // 支持两种格式：1. 直接的字符串数组 2. 包含quotes属性的对象
      if (Array.isArray(jsonData)) {
        // 直接的字符串数组格式
        quotes = jsonData.map((text: string): Quote => {
          return {
            id: (Date.now() + Math.random()).toString(),
            text: text.trim(),
            tags: [],
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
          } as Quote;
        });
      } else if (jsonData.quotes && Array.isArray(jsonData.quotes)) {
        // 标准的导出格式
        quotes = jsonData.quotes;
      } else {
        throw new Error('文件格式不正确');
      }
      let importCount = 0;
      for (const quote of quotes) {
        if (quote.text && quote.text.trim()) {
          const addQuoteData: AddQuoteParams = {
            text: quote.text,
            tags: quote.tags || []
          };
          await this.quoteManager.addQuote(addQuoteData);
          importCount++;
        }
      }
      this.selectedFile = '';
      const successToast: ShowToastOptions = {
        message: `成功导入${importCount}条语录`
      };
      promptAction.showToast(successToast);
    } catch (error) {
      console.error('导入数据失败:', error);
      const errorToast: ShowToastOptions = {
        message: '导入失败', // 正确初始化对象
        duration: 2000
      };
      promptAction.showToast(errorToast);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 返回上一页
   */
  goBack() {
    router.back();
  }

  /**
   * 构建页面UI
   */
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor('#007AFF')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.goBack())
        Text('数据管理')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button() {
          Text('帮助')
            .fontSize(16)
            .fontColor('#007AFF')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          // 修复 showDialog 调用
          const dialogOptions: ShowDialogOptions = {
            title: '使用说明',
            message: '• 导出：将当前所有语录保存为JSON文件\n• 导入：从JSON文件中导入语录数据\n注意：导入会追加数据，不会覆盖现有数据', // 修复字符串和换行符
            buttons: [{ // 修复 buttons 格式
              text: '知道了',
              color: '#007AFF'
            }]
          };
          promptAction.showDialog(dialogOptions); // 传递正确类型的对象
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#E5E5E5' })
      Scroll() {
        Column() {
          // 导出功能卡片
          Column() {
            Row() {
              Column() {
                Row() {
                  Image($r('app.media.ic_daochu'))
                    .width(40)
                    .height(40)

                    .margin({ right: 16 })
                  Column() {
                    Text('导出数据')
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1D1D1F')
                    Text('将所有语录导出为JSON文件')
                      .fontSize(14)
                      .fontColor('#86868B')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 12 })
            Button('导出数据')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#007AFF')
              .backgroundColor('#E3F2FD')
              .borderRadius(12)
              .enabled(!this.isLoading)
              .onClick(() => this.exportData())
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ bottom: 12 })
          .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
          // 导入功能卡片
          Column() {
            Row() {
              Column() {
                Row() {
                  Image($r('app.media.ic_daoru'))
                    .width(40)
                    .height(40)

                    .margin({ right: 16 })
                  Column() {
                    Text('导入数据')
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1D1D1F')
                    Text('从JSON文件导入语录数据')
                      .fontSize(14)
                      .fontColor('#86868B')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 20 })
            if (this.selectedFile) {
              Column() {
                Text('已选择文件')
                  .fontSize(12)
                  .fontColor('#86868B')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 6 })
                Text(this.selectedFile.split('/').pop() || '')
                  .fontSize(14)
                  .fontColor('#1D1D1F')
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F2F2F7')
              .borderRadius(12)
              .margin({ bottom: 16 })
            }
            Row() {
              Button('选择文件')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#007AFF')
                .backgroundColor('#E3F2FD')
                .borderRadius(12)
                .enabled(!this.isLoading)
                .onClick(() => this.selectImportFile())
              if (this.selectedFile) {
                Button('开始导入')
                  .layoutWeight(1)
                  .height(48)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#34C759')
                  .borderRadius(12)
                  .margin({ left: 12 })
                  .enabled(!this.isLoading)
                  .onClick(() => this.confirmImport())
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ bottom: 20 }) // 原来分享卡片的位置留出一些间距
          .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
          // 已删除分享功能卡片的整个 Column 块
        }
        .padding({ left: 20, right: 20, top: 0, bottom: 20 })
      }
      .layoutWeight(1)
      .backgroundColor('#F8F9FA')
      // 加载状态
      if (this.isLoading) {
        Row() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color('#007AFF')
          Text('处理中...')
            .fontSize(16)
            .fontColor('#1D1D1F')
            .fontWeight(FontWeight.Medium)
            .margin({ left: 12 })
        }
        .width('100%')
        .height(60)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.95)')
        .borderRadius({ topLeft: 16, topRight: 16 })
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.1)', offsetY: -2 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}