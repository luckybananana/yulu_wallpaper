import { preferences } from '@kit.ArkData';
import { resourceManager } from '@kit.LocalizationKit';
import { Context } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

// 语录数据接口
export interface Quote {
  id: string;
  text: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

// 统计信息接口
interface StatisticsInfo {
  totalCount: number;
  categoryCount: number;
  categories: Record<string, number>;
}

// 导入数据项接口
interface ImportQuoteItem {
  id?: string;
  text?: string;
  content?: string;
  tags?: string[];
  createdAt?: string;
  updatedAt?: string;
}

// 更新语录参数接口
export interface UpdateQuoteParams {
  text?: string;
  tags?: string[];
  updatedAt?: string;
}

// 新增语录参数接口
export interface AddQuoteParams {
  text: string;
  tags: string[];
}

// 数据管理器类
export class QuoteDataManager {
  private static instance: QuoteDataManager;
  private context: Context;
  private dataStore: preferences.Preferences | null = null;
  private quotes: Quote[] = [];
  private isInitialized: boolean = false;

  constructor(context: Context) {
    this.context = context;
  }

  // 获取单例实例
  public static getInstance(context?: Context): QuoteDataManager {
    if (!QuoteDataManager.instance) {
      if (!context) {
        throw new Error('Context is required for first initialization');
      }
      QuoteDataManager.instance = new QuoteDataManager(context);
    }
    return QuoteDataManager.instance;
  }

  // 初始化数据存储
  public async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // 初始化preferences数据存储
      this.dataStore = await preferences.getPreferences(this.context, 'quotes_data');
      
      // 加载本地存储的语录
      await this.loadQuotesFromStorage();
      
      // 如果没有本地数据，加载初始数据
      if (this.quotes.length === 0) {
        await this.loadInitialQuotes();
      }
      
      this.isInitialized = true;
    } catch (error) {
      console.error('初始化数据管理器失败:', error);
      throw new Error('初始化失败');
    }
  }

  // 从本地存储加载语录
  private async loadQuotesFromStorage(): Promise<void> {
    try {
      if (!this.dataStore) {
        return;
      }
      
      const quotesJson = await this.dataStore.get('quotes', '[]') as string;
      this.quotes = JSON.parse(quotesJson);
    } catch (error) {
      console.error('从本地存储加载语录失败:', error);
      this.quotes = [];
    }
  }

  // 加载初始语录数据
  private async loadInitialQuotes(): Promise<void> {
    try {
      const resMgr = this.context.resourceManager;
      const quotesBuffer = await resMgr.getRawFileContent('quotes.json');
      const quotesText = util.TextDecoder.create('utf-8').decodeWithStream(quotesBuffer);
      const initialQuotes: string[] = JSON.parse(quotesText);
      
      // 转换为标准格式
      this.quotes = initialQuotes.map((quoteText: string, index: number): Quote => ({
        id: this.generateId(),
        text: quoteText.trim(),
        tags: [],
        createdAt: new Date(Date.now() - (initialQuotes.length - index) * 1000).toISOString(),
        updatedAt: new Date(Date.now() - (initialQuotes.length - index) * 1000).toISOString()
      }));
      
      // 保存到本地存储
      await this.saveQuotesToStorage();
    } catch (error) {
      console.error('加载初始语录数据失败:', error);
      this.quotes = [];
    }
  }

  // 保存语录到本地存储
  private async saveQuotesToStorage(): Promise<void> {
    try {
      if (!this.dataStore) {
        return;
      }
      
      const quotesJson = JSON.stringify(this.quotes);
      await this.dataStore.put('quotes', quotesJson);
      await this.dataStore.flush();
    } catch (error) {
      console.error('保存语录到本地存储失败:', error);
      throw new Error('保存语录失败');
    }
  }

  // 生成唯一ID
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substring(2);
  }

  // 获取所有语录
  public async getAllQuotes(): Promise<Quote[]> {
    await this.initialize();
    const result: Quote[] = [];
    for (let i = 0; i < this.quotes.length; i++) {
      result.push(this.quotes[i]);
    }
    return result;
  }

  // 根据ID获取语录
  public async getQuoteById(id: string): Promise<Quote | null> {
    await this.initialize();
    return this.quotes.find(quote => quote.id === id) || null;
  }

  // 添加新语录
  public async addQuote(quoteData: AddQuoteParams): Promise<Quote> {
    await this.initialize();
    
    const newQuote: Quote = {
      id: this.generateId(),
      text: quoteData.text,
      tags: quoteData.tags,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    this.quotes.unshift(newQuote);
    await this.saveQuotesToStorage();
    
    return newQuote;
  }

  // 更新语录
  public async updateQuote(id: string, updates: UpdateQuoteParams): Promise<Quote | null> {
    await this.initialize();
    
    const index = this.quotes.findIndex(quote => quote.id === id);
    if (index === -1) {
      return null;
    }
    
    const updatedQuote: Quote = {
      id: this.quotes[index].id,
      text: updates.text !== undefined ? updates.text : this.quotes[index].text,
      tags: updates.tags !== undefined ? updates.tags : this.quotes[index].tags,
      createdAt: this.quotes[index].createdAt,
      updatedAt: new Date().toISOString()
    };
    
    this.quotes[index] = updatedQuote;
    
    await this.saveQuotesToStorage();
    return this.quotes[index];
  }

  // 删除语录
  public async deleteQuote(id: string): Promise<boolean> {
    await this.initialize();
    
    const index = this.quotes.findIndex(quote => quote.id === id);
    if (index === -1) {
      return false;
    }
    
    this.quotes.splice(index, 1);
    await this.saveQuotesToStorage();
    
    return true;
  }

  // 批量删除语录
  public async deleteQuotes(ids: string[]): Promise<number> {
    await this.initialize();
    
    let deletedCount = 0;
    for (const id of ids) {
      const index = this.quotes.findIndex(quote => quote.id === id);
      if (index !== -1) {
        this.quotes.splice(index, 1);
        deletedCount++;
      }
    }
    
    if (deletedCount > 0) {
      await this.saveQuotesToStorage();
    }
    
    return deletedCount;
  }

  // 搜索语录
  public async searchQuotes(keyword: string): Promise<Quote[]> {
    await this.initialize();
    
    if (!keyword.trim()) {
      return [...this.quotes];
    }
    
    const lowerKeyword = keyword.toLowerCase();
    return this.quotes.filter(quote => 
      quote.text.toLowerCase().includes(lowerKeyword) ||
      quote.tags.some(tag => tag.toLowerCase().includes(lowerKeyword))
    );
  }



  // 获取随机语录
  public async getRandomQuote(): Promise<Quote | null> {
    await this.initialize();
    
    if (this.quotes.length === 0) {
      return null;
    }
    
    const randomIndex = Math.floor(Math.random() * this.quotes.length);
    return this.quotes[randomIndex];
  }

  // 导出所有语录
  public async exportQuotes(): Promise<string> {
    await this.initialize();
    return JSON.stringify(this.quotes, null, 2);
  }

  // 导入语录
  public async importQuotes(quotesJson: string, replaceAll: boolean = false): Promise<number> {
    await this.initialize();
    
    try {
      const importedQuotes: ImportQuoteItem[] = JSON.parse(quotesJson);
      
      if (!Array.isArray(importedQuotes)) {
        throw new Error('导入数据格式错误');
      }
      
      // 验证和转换数据格式
      const validQuotes: Quote[] = importedQuotes
        .filter((item: ImportQuoteItem) => item && (item.text || item.content))
        .map((item: ImportQuoteItem): Quote => ({
          id: item.id || this.generateId(),
          text: item.text || item.content || '',
          tags: Array.isArray(item.tags) ? item.tags : [],
          createdAt: item.createdAt || new Date().toISOString(),
          updatedAt: item.updatedAt || new Date().toISOString()
        }));
      
      if (replaceAll) {
        this.quotes = validQuotes;
      } else {
        // 合并数据，避免重复
        const existingIds = new Set(this.quotes.map(q => q.id));
        const newQuotes = validQuotes.filter(q => !existingIds.has(q.id));
        this.quotes = [...newQuotes, ...this.quotes];
      }
      
      await this.saveQuotesToStorage();
      return validQuotes.length;
    } catch (error) {
      console.error('导入语录失败:', error);
      throw new Error('导入语录失败');
    }
  }

  // 获取统计信息
  public async getStatistics(): Promise<StatisticsInfo> {
    await this.initialize();
    
    return {
      totalCount: this.quotes.length,
      categoryCount: 0,
      categories: {}
    };
  }

  // 清空所有语录
  public async clearAllQuotes(): Promise<void> {
    await this.initialize();
    this.quotes = [];
    await this.saveQuotesToStorage();
  }
}