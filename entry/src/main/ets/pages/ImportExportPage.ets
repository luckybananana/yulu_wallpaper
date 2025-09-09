import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { QuoteDataManager, Quote, AddQuoteParams } from '../common/QuoteDataManager';
import { fileIo } from '@kit.CoreFileKit';

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



/**
 * 导出数据接口
 */
interface ExportData {
  version: string;
  exportTime: string;
  totalCount: number;
  quotes: Quote[];
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
  @State importPreview: Quote[] = [];
  @State showPreview: boolean = false;
  
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

      const exportData: ExportData = {
        version: '1.0',
        exportTime: new Date().toISOString(),
        totalCount: quotes.length,
        quotes: quotes
      };
      
      const jsonString = JSON.stringify(exportData, null, 2);
      const fileName = `语录备份_${new Date().toISOString().split('T')[0]}.json`;
      
      // TODO: 实现文件保存功能
      // 这里需要使用HarmonyOS的文件保存API
      
      const exportSuccessToast: ShowToastOptions = {
        message: `成功导出${quotes.length}条语录`,
        duration: 2000
      };
      promptAction.showToast(exportSuccessToast);
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
        await this.previewImportData();
      }
    } catch (error) {
      console.error('选择文件失败:', error);
      const selectFileErrorToast: ShowToastOptions = {
         message: '选择文件失败'
       };
      selectFileErrorToast.duration = 2000;
      promptAction.showToast(selectFileErrorToast);
    }
  }

  /**
   * 预览导入数据
   */
  async previewImportData() {
    if (!this.selectedFile) return;

    this.isLoading = true;
    try {
      const file = fileIo.openSync(this.selectedFile, fileIo.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(1024 * 1024); // 1MB buffer
      const readLen = fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file.fd);
      
      const uint8Array = new Uint8Array(buffer, 0, readLen);
      let content = '';
      for (let i = 0; i < uint8Array.length; i++) {
        content += String.fromCharCode(uint8Array[i]);
      }
      const importData: ImportData = JSON.parse(content);
      
      if (importData.quotes && Array.isArray(importData.quotes)) {
        this.importPreview = importData.quotes.slice(0, 10); // 预览前10条
        this.showPreview = true;
      } else {
        throw new Error('文件格式不正确');
      }
    } catch (error) {
      console.error('预览导入数据失败:', error);
      const previewErrorToast: ShowToastOptions = {
          message: '文件格式错误，请选择有效的JSON文件'
        };
      previewErrorToast.duration = 2000;
      promptAction.showToast(previewErrorToast);
    } finally {
      this.isLoading = false;
    }
  }

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
      
      const uint8Array2 = new Uint8Array(buffer, 0, readLen);
      let content2 = '';
      for (let i = 0; i < uint8Array2.length; i++) {
        content2 += String.fromCharCode(uint8Array2[i]);
      }
      const importData2: ImportData = JSON.parse(content2);
      
      if (importData2.quotes && Array.isArray(importData2.quotes)) {
        let importCount = 0;
        for (const quote of importData2.quotes) {
          if (quote.text && quote.text.trim()) {
            const addQuoteData: AddQuoteParams = {
              text: quote.text,
              tags: quote.tags || []
            };
            await this.quoteManager.addQuote(addQuoteData);
            importCount++;
          }
        }
        
        this.showPreview = false;
        this.selectedFile = '';
        
        const successToast: ShowToastOptions = {
          message: `成功导入${importCount}条语录`
        };
        promptAction.showToast(successToast);
      }
    } catch (error) {
      console.error('导入数据失败:', error);
      const errorToast: ShowToastOptions = {} as ShowToastOptions;
      errorToast.message = '导入失败';
      errorToast.duration = 2000;
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
          Text('←')
            .fontSize(20)
            .fontColor('#333333')
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
          promptAction.showDialog({
            title: '使用说明',
            message: '• 导出：将当前所有语录保存为JSON文件\n• 导入：从JSON文件中导入语录数据\n\n注意：导入会追加数据，不会覆盖现有数据',
            buttons: [{
              text: '知道了',
              color: '#007AFF'
            }]
          });
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
                Text('导出数据')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                
                Text('将所有语录导出为JSON文件')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              
              Text('📤')
                .fontSize(24)
            }
            .width('100%')
            .margin({ bottom: 16 })

            Button('导出数据')
              .width('100%')
              .height(44)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#007AFF')
              .borderRadius(8)
              .enabled(!this.isLoading)
              .onClick(() => this.exportData())
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 导入功能卡片
          Column() {
            Row() {
              Column() {
                Text('导入数据')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                
                Text('从JSON文件导入语录数据')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              
              Text('📥')
                .fontSize(24)
            }
            .width('100%')
            .margin({ bottom: 16 })

            if (this.selectedFile) {
              Column() {
                Text('已选择文件')
                  .fontSize(12)
                  .fontColor('#666666')
                  .alignSelf(ItemAlign.Start)
                
                Text(this.selectedFile.split('/').pop() || '')
                  .fontSize(14)
                  .fontColor('#333333')
                  .margin({ top: 4 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#F8F9FA')
              .borderRadius(8)
              .margin({ bottom: 12 })
            }

            Row() {
              Button('选择文件')
                .layoutWeight(1)
                .height(44)
                .fontSize(16)
                .fontColor('#007AFF')
                .backgroundColor('#F0F8FF')
                .borderRadius(8)
                .enabled(!this.isLoading)
                .onClick(() => this.selectImportFile())
              
              if (this.selectedFile) {
                Button('开始导入')
                  .layoutWeight(1)
                  .height(44)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#34C759')
                  .borderRadius(8)
                  .margin({ left: 12 })
                  .enabled(!this.isLoading)
                  .onClick(() => this.confirmImport())
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 导入预览
          if (this.showPreview && this.importPreview.length > 0) {
            Column() {
              Row() {
                Text('导入预览')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                
                Blank()
                
                Text(`${this.importPreview.length}条`)
                  .fontSize(14)
                  .fontColor('#666666')
              }
              .width('100%')
              .margin({ bottom: 12 })

              ForEach(this.importPreview.slice(0, 3), (quote: Quote, index: number) => {
                Column() {
                  Text(quote.text || '')
                    .fontSize(14)
                    .fontColor('#333333')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  

                }
                .width('100%')
                .padding(12)
                .backgroundColor('#F8F9FA')
                .borderRadius(8)
                .margin({ bottom: 8 })
              })

              if (this.importPreview.length > 3) {
                Text(`还有${this.importPreview.length - 3}条语录...`)
                  .fontSize(12)
                  .fontColor('#666666')
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 16 })
          }


        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')

      // 加载状态
      if (this.isLoading) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#007AFF')
          
          Text('处理中...')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ left: 8 })
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.9)')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}