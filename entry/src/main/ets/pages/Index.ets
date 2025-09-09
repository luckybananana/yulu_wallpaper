import { promptAction, router } from '@kit.ArkUI';
import { QuoteDataManager, Quote } from '../common/QuoteDataManager';

// Toast选项接口
interface ShowToastOptions {
  message: string;
  duration?: number;
}

@Entry
@Component
struct Index {
  @State quotes: Quote[] = [];
  @State isMultiSelectMode: boolean = false;
  @State selectedQuotes: Set<string> = new Set();
  @State isLoading: boolean = true;
  @State showActionMenu: boolean = false;
  @State currentQuote: Quote | null = null;
  @State isSearchMode: boolean = false;
  @State searchKeyword: string = '';
  @State filteredQuotes: Quote[] = [];
  
  private dataManager: QuoteDataManager = QuoteDataManager.getInstance(getContext(this));

  async aboutToAppear() {
    await this.loadData();
  }

  // 页面显示时刷新数据
  async onPageShow() {
    await this.loadData();
  }

  async loadData() {
    try {
      this.isLoading = true;
      await this.dataManager.initialize();
      this.quotes = await this.dataManager.getAllQuotes();
    } catch (error) {
      console.error('加载数据失败:', error);
      const loadErrorToast: ShowToastOptions = {
        message: '加载语录失败，请重试'
      };
      promptAction.showToast(loadErrorToast);
    } finally {
      this.isLoading = false;
    }
  }

  // 显示操作菜单
  showQuoteActionMenu(quote: Quote) {
    if (this.isMultiSelectMode) {
      this.toggleQuoteSelection(quote.id);
      return;
    }
    this.currentQuote = quote;
    this.showActionMenu = true;
  }

  // 隐藏操作菜单
  hideQuoteActionMenu() {
    this.showActionMenu = false;
    this.currentQuote = null;
  }

  // 切换语录选择状态
  toggleQuoteSelection(quoteId: string) {
    if (!this.isMultiSelectMode) {
      this.enterMultiSelectMode();
    }

    if (this.selectedQuotes.has(quoteId)) {
      this.selectedQuotes.delete(quoteId);
    } else {
      this.selectedQuotes.add(quoteId);
    }

    // 如果没有选中任何项，退出多选模式
    if (this.selectedQuotes.size === 0) {
      this.exitMultiSelectMode();
    }
  }

  // 进入多选模式
  enterMultiSelectMode() {
    this.isMultiSelectMode = true;
  }

  // 退出多选模式
  exitMultiSelectMode() {
    this.isMultiSelectMode = false;
    this.selectedQuotes.clear();
  }

  // 全选/取消全选
  toggleSelectAll() {
    const currentQuotes = this.getCurrentQuotes();
    const allSelected = this.selectedQuotes.size === currentQuotes.length;
    
    if (allSelected) {
      this.selectedQuotes.clear();
      this.exitMultiSelectMode();
    } else {
      this.selectedQuotes.clear();
      currentQuotes.forEach(quote => this.selectedQuotes.add(quote.id));
    }
  }

  // 删除选中的语录
  async deleteSelectedQuotes() {
    if (this.selectedQuotes.size === 0) return;

    try {
      const ids = Array.from(this.selectedQuotes);
      const deletedCount = await this.dataManager.deleteQuotes(ids);
      const deleteSuccessToast: ShowToastOptions = {
        message: '删除成功'
      };
      promptAction.showToast(deleteSuccessToast);
      
      this.exitMultiSelectMode();
      await this.loadData();
    } catch (error) {
      console.error('删除语录失败:', error);
      const deleteErrorToast: ShowToastOptions = {
        message: '删除失败，请重试'
      };
      promptAction.showToast(deleteErrorToast);
    }
  }

  // 新增语录
  addQuote() {
    this.hideQuoteActionMenu();
    router.pushUrl({
      url: 'pages/EditPage'
    });
  }

  // 编辑语录
  editQuote() {
    this.hideQuoteActionMenu();
    if (this.currentQuote) {
      router.pushUrl({
        url: 'pages/EditPage',
        params: { quote: JSON.stringify(this.currentQuote), mode: 'edit' }
      }).catch((error: Error) => {
        console.error('跳转编辑页面失败:', error);
        const errorToast: ShowToastOptions = {
          message: '跳转失败，请重试'
        };
        promptAction.showToast(errorToast);
      });
    }
  }

  // 删除单个语录
  async deleteSingleQuote() {
    this.hideQuoteActionMenu();
    if (this.currentQuote) {
      try {
        // 显示确认对话框
        promptAction.showDialog({
          title: '确认删除',
          message: '确定要删除这条语录吗？此操作不可撤销。',
          buttons: [
            {
              text: '取消',
              color: '#666666'
            },
            {
              text: '删除',
              color: '#FF3B30'
            }
          ]
        }).then(async (result) => {
          if (result.index === 1) { // 用户点击了删除
            try {
              await this.dataManager.deleteQuotes([this.currentQuote!.id]);
              const deleteSuccessToast: ShowToastOptions = {
                message: '删除成功'
              };
              promptAction.showToast(deleteSuccessToast);
              await this.loadData();
            } catch (error) {
              console.error('删除语录失败:', error);
              const deleteErrorToast: ShowToastOptions = {
                message: '删除失败，请重试'
              };
              promptAction.showToast(deleteErrorToast);
            }
          }
        }).catch((error: Error) => {
          console.error('显示删除确认对话框失败:', error);
        });
      } catch (error) {
        console.error('删除操作失败:', error);
        const deleteErrorToast: ShowToastOptions = {
          message: '删除失败，请重试'
        };
        promptAction.showToast(deleteErrorToast);
      }
    }
  }

  // 预览壁纸
  previewWallpaper() {
    this.hideQuoteActionMenu();
    if (this.currentQuote) {
      router.pushUrl({
        url: 'pages/WallpaperPage',
        params: { quote: JSON.stringify(this.currentQuote) }
      }).catch((error: Error) => {
        console.error('跳转壁纸预览页面失败:', error);
        const errorToast: ShowToastOptions = {
          message: '跳转失败，请重试'
        };
        promptAction.showToast(errorToast);
      });
    }
  }

  // 打开设置
  openSettings() {
    router.pushUrl({
      url: 'pages/SettingsPage'
    });
  }

  // 打开导入导出
  openImportExport() {
    router.pushUrl({
      url: 'pages/ImportExportPage'
    });
  }

  // 切换搜索模式
  toggleSearchMode() {
    this.isSearchMode = !this.isSearchMode;
    if (!this.isSearchMode) {
      this.searchKeyword = '';
      this.filteredQuotes = [];
    }
  }

  // 执行搜索
  async performSearch() {
    if (this.searchKeyword.trim() === '') {
      this.filteredQuotes = [];
      return;
    }
    
    try {
      this.filteredQuotes = await this.dataManager.searchQuotes(this.searchKeyword);
    } catch (error) {
      console.error('搜索失败:', error);
      const searchErrorToast: ShowToastOptions = {
        message: '搜索失败，请重试'
      };
      promptAction.showToast(searchErrorToast);
    }
  }

  // 获取当前显示的语录列表
  getCurrentQuotes(): Quote[] {
    if (this.isSearchMode && this.searchKeyword.trim() !== '') {
      return this.filteredQuotes;
    }
    return this.quotes;
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏（正常模式）
        if (!this.isMultiSelectMode) {
          Column() {
            Row() {
              Text('语录壁纸')
                .fontSize(20)
                .fontWeight(600)
                .fontColor('#1A1A1A')
                .layoutWeight(1)
              
              Button() {
                Image($r('app.media.ic_search'))
                  .width(20)
                  .height(20)
                  .fillColor('#666666')
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .borderRadius(20)
              .onClick(() => {
                this.toggleSearchMode();
              })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            
            // 搜索输入框
            if (this.isSearchMode) {
              Row() {
                TextInput({ placeholder: '搜索语录内容', text: this.searchKeyword })
                  .layoutWeight(1)
                  .height(40)
                  .borderRadius(20)
                  .backgroundColor('#F5F5F5')
                  .padding({ left: 16, right: 16 })
                  .onChange((value: string) => {
                    this.searchKeyword = value;
                    this.performSearch();
                  })
                
                Button('取消')
                  .fontSize(14)
                  .fontColor('#4A90E2')
                  .backgroundColor(Color.Transparent)
                  .padding({ left: 12, right: 0 })
                  .onClick(() => {
                    this.toggleSearchMode();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
            }
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .border({ width: { bottom: 1 }, color: '#E1E5E9' })
        }

        // 多选模式顶部栏
        if (this.isMultiSelectMode) {
          Row() {
            Row({ space: 16 }) {
              Button() {
                Image($r('app.media.ic_close'))
                  .width(20)
                  .height(20)
                  .fillColor('#FFFFFF')
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.exitMultiSelectMode())
              
              Text(`已选择 ${this.selectedQuotes.size} 条`)
                .fontSize(16)
                .fontWeight(500)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            
            Row({ space: 16 }) {
              Button() {
                Image($r('app.media.ic_select_all'))
                  .width(20)
                  .height(20)
                  .fillColor('#FFFFFF')
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.toggleSelectAll())
              
              Button() {
                Image($r('app.media.ic_delete'))
                  .width(20)
                  .height(20)
                  .fillColor('#FFFFFF')
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.deleteSelectedQuotes())
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#4A90E2')
          .justifyContent(FlexAlign.SpaceBetween)
        }

        // 语录列表容器
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#4A90E2')
              .margin({ bottom: 16 })
            Text('加载中...')
              .fontSize(16)
              .fontColor('#666666')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F8F9FA')
        } else if (this.getCurrentQuotes().length === 0) {
          // 空状态
          Column() {
            Text('💬')
              .fontSize(48)
              .margin({ bottom: 16 })
            Text(this.isSearchMode && this.searchKeyword.trim() !== '' ? '未找到相关语录' : '还没有语录')
              .fontSize(18)
              .fontColor('#666666')
              .margin({ bottom: 8 })
            Text(this.isSearchMode && this.searchKeyword.trim() !== '' ? '尝试使用其他关键词搜索' : '点击下方的 + 按钮\n添加你的第一条语录吧')
              .fontSize(14)
              .fontColor('#999999')
              .textAlign(TextAlign.Center)
              .lineHeight(20)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F8F9FA')
        } else {
          // 语录列表
          List({ space: 12 }) {
            ForEach(this.getCurrentQuotes(), (quote: Quote) => {
              ListItem() {
                Stack() {
                  // 语录卡片
                  Column() {
                    Text(quote.text)
                      .fontSize(16)
                      .fontColor('#1A1A1A')
                      .lineHeight(25.6)
                      .fontWeight(400)
                      .margin({ bottom: 12 })
                      .width('100%')
                    

                  }
                  .width('100%')
                  .padding(20)
                  .backgroundColor('#FFFFFF')
                  .borderRadius(12)
                  .shadow({
                    radius: 3,
                    color: 'rgba(0,0,0,0.12)',
                    offsetX: 0,
                    offsetY: 1
                  })
                  .border({
                    width: this.selectedQuotes.has(quote.id) ? 2 : 0,
                    color: '#4A90E2'
                  })
                  .backgroundColor(this.selectedQuotes.has(quote.id) ? 'rgba(74, 144, 226, 0.05)' : '#FFFFFF')
                  .onClick(() => this.showQuoteActionMenu(quote))
                  .gesture(
                    LongPressGesture({ repeat: false })
                      .onAction(() => {
                        if (!this.isMultiSelectMode) {
                          this.toggleQuoteSelection(quote.id);
                        }
                      })
                  )
                  
                  // 多选模式复选框
                  if (this.isMultiSelectMode) {
                    Row() {
                      if (this.selectedQuotes.has(quote.id)) {
                        Image($r('app.media.ic_check'))
                          .width(12)
                          .height(12)
                          .fillColor('#FFFFFF')
                      }
                    }
                    .width(20)
                    .height(20)
                    .backgroundColor(this.selectedQuotes.has(quote.id) ? '#4A90E2' : '#FFFFFF')
                    .border({ width: 2, color: '#4A90E2' })
                    .borderRadius(4)
                    .justifyContent(FlexAlign.Center)
                    .position({ x: '100%', y: 0 })
                    .translate({ x: -36, y: 16 })
                  }
                }
              }
            })
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 16 })
          .backgroundColor('#F8F9FA')
          .scrollBar(BarState.Off)
        }

        // 底部操作栏
        Row() {
          // 导入导出按钮
          Column({ space: 4 }) {
            Image($r('app.media.ic_import_export'))
              .width(20)
              .height(20)
              .fillColor('#666666')
            Text('导入导出')
              .fontSize(12)
              .fontColor('#666666')
          }
          .padding({ top: 8, bottom: 8, left: 12, right: 12 })
          .borderRadius(8)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.openImportExport())
          .layoutWeight(1)
          
          // 新增按钮（FAB样式）
          Button() {
            Image($r('app.media.ic_add'))
              .width(24)
              .height(24)
              .fillColor('#FFFFFF')
          }
          .width(56)
          .height(56)
          .backgroundColor('#4A90E2')
          .borderRadius(28)
          .shadow({
            radius: 6,
            color: 'rgba(0,0,0,0.16)',
            offsetX: 0,
            offsetY: 3
          })
          .onClick(() => this.addQuote())
          
          // 设置按钮
          Column({ space: 4 }) {
            Image($r('app.media.ic_settings'))
              .width(20)
              .height(20)
              .fillColor('#666666')
            Text('设置')
              .fontSize(12)
              .fontColor('#666666')
          }
          .padding({ top: 8, bottom: 8, left: 12, right: 12 })
          .borderRadius(8)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.openSettings())
          .layoutWeight(1)
        }
        .width('100%')
        .height(80)
        .padding({ left: 20, right: 20 })
        .backgroundColor('#FFFFFF')
        .border({ width: { top: 1 }, color: '#E1E5E9' })
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F9FA')

      // 操作菜单弹窗
      if (this.showActionMenu) {
        Column() {
          // 遮罩层
          Row()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('rgba(0,0,0,0.5)')
            .onClick(() => this.hideQuoteActionMenu())
          
          // 菜单内容
          Column() {
            Row() {
              Text('选择操作')
                .fontSize(18)
                .fontWeight(600)
                .fontColor('#1A1A1A')
                .layoutWeight(1)
              
              Button() {
                Image($r('app.media.ic_close'))
                  .width(20)
                  .height(20)
                  .fillColor('#666666')
              }
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
              .borderRadius(20)
              .onClick(() => this.hideQuoteActionMenu())
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 操作按钮网格
            Row({ space: 12 }) {
              // 修改语录
              Column({ space: 6 }) {
                Image($r('app.media.ic_edit'))
                  .width(20)
                  .height(20)
                  .fillColor('#1A1A1A')
                Text('修改语录')
                  .fontSize(12)
                  .fontWeight(500)
                  .fontColor('#1A1A1A')
                  .textAlign(TextAlign.Center)
              }
              .width(80)
              .height(80)
              .padding({ top: 16, bottom: 8, left: 8, right: 8 })
              .backgroundColor('#F8F9FA')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.editQuote())
              .layoutWeight(1)
              
              // 删除语录
              Column({ space: 6 }) {
                Image($r('app.media.ic_delete'))
                  .width(20)
                  .height(20)
                  .fillColor('#FF3B30')
                Text('删除语录')
                  .fontSize(12)
                  .fontWeight(500)
                  .fontColor('#1A1A1A')
                  .textAlign(TextAlign.Center)
              }
              .width(80)
              .height(80)
              .padding({ top: 16, bottom: 8, left: 8, right: 8 })
              .backgroundColor('#F8F9FA')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.deleteSingleQuote())
              .layoutWeight(1)
              
              // 壁纸预览
              Column({ space: 6 }) {
                Image($r('app.media.ic_preview'))
                  .width(20)
                  .height(20)
                  .fillColor('#1A1A1A')
                Text('壁纸预览')
                  .fontSize(12)
                  .fontWeight(500)
                  .fontColor('#1A1A1A')
                  .textAlign(TextAlign.Center)
              }
              .width(80)
              .height(80)
              .padding({ top: 16, bottom: 8, left: 8, right: 8 })
              .backgroundColor('#F8F9FA')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.previewWallpaper())
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius({ topLeft: 16, topRight: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .height('100%')
  }
}