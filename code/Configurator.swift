//
//  Configurator.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 13/08/2021.
//

import PerfectLib
//https://github.com/iamjono/JSONConfig/blob/281aa95ec18057017cbe78a55a9ef403b794d0a9/Sources/JSONConfig/jsonConfig.swift sto usando il suo codice (JSONConfig) con qualche modifica perche' non mi piaceva il suo error handling
import Foundation


public enum ConfigError:Error{
    case IOError(alert:String)
    case JSONDecodeError(alert:String)
    case FileDoesNotExist(file:String)
    case MissingConfigError(missingConfig:String)
    case BadFormatError(in:String,info:String)
    case BadTypeError(type:String,in:String)
    case BadTemplateError(String)
    case RepeatedAttributeError(attribute:String)
    case TemplateNotFound(template:Dictionary<String,String>)
}

public protocol Configurator{
    var path:String {get}
    init(path:String) throws
    func getConfigSchema() throws -> ConfigSchema
}

public struct MyJSONConfigurator:Configurator{
    public let path:String
    private let contentOfConfigurationFile:Dictionary<String,Any>
    
    public init(path:String) throws{
        self.path = path
        //durante il normale utilizzo funziona, anche se l'intero file di configurazione viene tirato in memoria normalmente non si hanno problemi; fatto cosi' per velocita'
        self.contentOfConfigurationFile = try JSONConfig(pathOfConfigurationFile: self.path).getValues()
    }
    
    public func getConfigSchema() throws -> ConfigSchema{
        var result:[Attribute:ConfigTaxonomy] = [:]
        guard self.contentOfConfigurationFile["schema"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "schema")}
        guard self.contentOfConfigurationFile["schema"] as? Dictionary<String, Any> != nil else{throw ConfigError.BadFormatError(in:"schema",info:"bad format of schema type, should be \(Dictionary<String,Any>.self)")}
        let schema = self.contentOfConfigurationFile["schema"] as! Dictionary<String, Any>

        //nessun controllo in caso ci sia lo stesso attributo definito in due diversi tipi di tassonomia
        result.merge(try getEmptyTax(schema: schema)){_,second in second }
        result.merge(try getQueryBasedTax(schema: schema)){_,second in second}
        result.merge(try getRuledTax(schema: schema)){_,second in second}
        let connector:ConnInfo = try self.getConnInfo()
        return ConfigSchema(conn:MyTaxonomyRetriever(conn: connector), attrTax: result)
    }
    
    private func getConnInfo() throws -> ConnInfo {
        guard self.contentOfConfigurationFile["connection"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "connection")}
        guard self.contentOfConfigurationFile["connection"] as? Dictionary<String,Any> != nil else {throw ConfigError.BadFormatError(in: "connection",info:"bad format of connection type, should be \(Dictionary<String,Any>.self)")}
        let conn = self.contentOfConfigurationFile["connection"] as! Dictionary<String,Any>
        
        guard conn["host"] != nil else{throw ConfigError.MissingConfigError(missingConfig: "host")}
        guard conn["host"] as? String != nil else{throw ConfigError.BadFormatError(in: "host",info:"bad format of host type, should be \(String.self)")}
        let host = conn["host"] as! String
        
        guard conn["user"] != nil else{throw ConfigError.MissingConfigError(missingConfig: "user")}
        guard conn["user"] as? String != nil else {throw ConfigError.BadFormatError(in: "user",info:"bad format of user type, should be \(String.self)")}
        let user = conn["user"] as! String
        
        let port:String?
        if let po = conn["port"]{
            port = po as? String
        }else{
            port = nil
        }
        
        guard conn["password"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "password")}
        guard conn["password"] as? String != nil else {throw ConfigError.BadFormatError(in: "password",info:"bad format of password type, should be \(String.self)")}
        let password = conn["password"] as! String

        guard conn["database"] != nil else{throw ConfigError.MissingConfigError(missingConfig: "database")}
        guard conn["database"] as? String != nil else{throw ConfigError.BadFormatError(in: "database",info:"bad format of database type, should be \(String.self)")}
        let database = conn["database"] as! String

        
        return ConnInfo(user: user, host: host, port: port, password: password, database: database)
    }
}

extension MyJSONConfigurator{
    
    private func getQueryBasedTax(schema:Dictionary<String,Any>) throws -> [Attribute:QueryBasedConfigTax]{
        guard schema["queryBasedTaxonomies"] != nil else {return [:]}
        guard schema["queryBasedTaxonomies"] as? [[String:Any]] != nil else {throw ConfigError.BadFormatError(in: "queryBasedTaxonomies",info:"bad format of queryBasedTaxonomies type, should be \([[String:Any]].self)")}
        let queryBased = schema["queryBasedTaxonomies"] as! [[String:Any]]
        
        var res:[Attribute:QueryBasedConfigTax] = [:]
        let reader:QueryBasedQueryReader = QueryBasedQueryReader.init()
        for tax in queryBased{
            if let name = tax["attribute"] as? String{
                let fix:[StaticTaxonomyQuery]
                let dyn:[DynamicTaxonomyQuery]
                let com:CommonChildrenTaxonomyQuery
                if let fixed = tax["fixed"] as? [Dictionary<String,String>]{
                    fix = try reader.getFixedQuery(fixed)
                }else{
                    throw ConfigError.BadFormatError(in: name,info:"bad format of fixed in queryBasedTaxonomies type, should be \([Dictionary<String,String>].self)")
                }
                if let dynamic = tax["dynamic"] as? [Dictionary<String,String>]{
                    dyn = try reader.getDynamicQuery(dynamic)
                }else{
                    throw ConfigError.BadFormatError(in: name,info:"bad format of dynamic in queryBasedTaxonomies type, should be \([Dictionary<String,String>].self)")
                }
                if let common = tax["commonChildren"] {
                    if common as? [Dictionary<String,String>] == nil {
                        throw ConfigError.BadFormatError(in: name, info: "bad format of commonChildren in queryBasedTaxonomies type, should be \([Dictionary<String,String>].self)")
                    }
                    com = try reader.getCommonChildrenQuery(common as! [Dictionary<String, String>])
                }else{
                    com = CommonChildrenTaxonomyQuery.init(templates: [])
                }
                do{
                    res[name] = try QueryBasedConfigTax.init(fixed: fix, dynamic: dyn,common: com)
                }catch{
                    throw QueryBasedConfigTaxError.NoCommonChildrenQueryProvided(taxonomy:name)
                }

            }else{
                throw ConfigError.MissingConfigError(missingConfig: "attribute in regularTaxonomies")
            }
        }
        return res
    }
    
    struct QueryBasedQueryReader{
        var staticTemplateReaders:[StaticTemplateReader.Type] = []
        var dynamicTemplateReaders:[DynamicTemplateReader.Type] = []
        var commonChildrenTemplateReaders:[CommonChildrenTemplateReader.Type] = []
        
        func getFixedQuery(_ dictionaries:[Dictionary<String,String>]) throws -> [StaticTaxonomyQuery]{
            var res:[StaticTaxonomyQuery] = []
            for dict in dictionaries{
                var notFound = true
                for templateType in self.staticTemplateReaders{
                    if let template = try templateType.fromRawToTemplate(rawTemplate: dict){
                        res.append(StaticTaxonomyQuery.init(template: template))
                        notFound = false
                        break
                    }else{
                        continue
                    }
                }
                if notFound{
                    throw ConfigError.TemplateNotFound(template: dict)
                }
            }
            return res
        }
        
        func getDynamicQuery(_ dictionaries:[Dictionary<String,String>]) throws -> [DynamicTaxonomyQuery]{
            var res:[DynamicTaxonomyQuery] = []
            for dict in dictionaries{
                var notFound = true
                for templateType in self.dynamicTemplateReaders{
                    if let template = try templateType.fromRawToTemplate(rawTemplate: dict){
                        res.append(DynamicTaxonomyQuery.init(template: template))
                        notFound = false
                        break
                    }else{
                        continue
                    }
                }
                if notFound{
                    throw ConfigError.TemplateNotFound(template: dict)
                }
            }
            return res
        }
        
        func getCommonChildrenQuery(_ dictionaries:[Dictionary<String,String>]) throws -> CommonChildrenTaxonomyQuery{
            var templates:[CommonChildrenTemplate] = []
            for dict in dictionaries{
                var notFound = true
                for templateType in self.commonChildrenTemplateReaders{
                    if let template = try templateType.fromRawToTemplate(rawTemplate: dict){
                        templates.append(template)
                        notFound = false
                        break
                    }else{
                        continue
                    }
                }
                if notFound{
                    throw ConfigError.TemplateNotFound(template: dict)
                }
            }
            return CommonChildrenTaxonomyQuery.init(templates: templates)
        }
        
        init(){
            self.staticTemplateReaders.append(contentsOf: [StaticArbitraryTemplate.self,SameTableTemplate.self,JoinTemplate.self,FlatTemplate.self])
            self.dynamicTemplateReaders.append(contentsOf: [DynamicArbitraryTemplate.self,SameTableTemplate.self,JoinTemplate.self])
            self.commonChildrenTemplateReaders.append(contentsOf: [CommonChildrenArbitraryTemplate.self])
        }
    }
}

extension MyJSONConfigurator{
    private func getEmptyTax(schema:Dictionary<String,Any>) throws-> [Attribute:EmptyConfigTax]{
        guard schema["emptyTaxonomies"] != nil else {return [:]}
        guard schema["emptyTaxonomies"] as? [[String:String]] != nil else {throw ConfigError.BadFormatError(in: "emptyTaxonomies",info:"bad format of emptyTaxonomies type, should be \([[String:String]].self)")}
        let empty = schema["emptyTaxonomies"] as! [[String:String]]

        var res:[Attribute:EmptyConfigTax] = [:]
        for tax in empty {
            if let name = tax["attribute"] {
                res[name] = EmptyConfigTax.init()
            }else{
                throw ConfigError.MissingConfigError(missingConfig: "missing attribute in emptyTaxonomies")
            }
        }
        return res
    }
}

extension MyJSONConfigurator{
    //poi aggiustare error handling
    private func getRuledTax(schema:Dictionary<String,Any>) throws -> [Attribute:RuleBasedConfigTax]{
        guard schema["ruledTaxonomies"] != nil else {return [:]}
        guard schema["ruledTaxonomies"] as? [[String:Any]] != nil else {throw ConfigError.BadFormatError(in: "ruledTaxonomies",info:"bad format of ruledTaxonomies type, should be \([[String:Any]].self)")}
        let ruled = schema["ruledTaxonomies"] as! [[String:Any]]

        var res:[Attribute:RuleBasedConfigTax] = [:]
        for tax in ruled{
            if let name = tax["attribute"] as? String{
                guard tax["intervals"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "missing intervals in ruledTaxonomies")}
                guard tax["intervals"] as? [[String:Any]] != nil else {throw
                    ConfigError.BadFormatError(in: "ruledTaxonomies",info:"bad format of intervals type, should be \([[String:Any]].self)")}
                let intervals = tax["intervals"] as! [[String:Any]]
                
                guard tax["parsingInformations"] != nil else {
                    throw ConfigError.MissingConfigError(missingConfig: "missing parsing informations in ruled taxonomies")
                }
                guard tax["parsingInformations"] as? [String:Any] != nil else {
                    throw ConfigError.BadFormatError(in: "ruled taxonomies", info: "bad format of parsing informations, should be \([String:Any].self)")
                }
                res[name] = try RuleBasedConfigTax.init(rules: try self.getRules(intervals: intervals),parser: self.getParsingInformations(informations: tax["parsingInformations"] as! [String:Any]))
            }else{
                throw ConfigError.MissingConfigError(missingConfig: "missing attribute in ruledTaxonomies")
            }
        }
        
        return res
    }
    
    private func getParsingInformations(informations:[String:Any]) throws -> MultidimensionalPointParser{
        let seps = informations["separatorsBetweenValues"]
        let weights = informations["weightOfValues"]
        let start = informations["startSeparator"]
        let end = informations["endSeparator"]
        guard seps != nil else {
            throw ConfigError.MissingConfigError(missingConfig: "missing separatorsBetweenValues in parser informations")
        }
        guard weights != nil else {
            throw ConfigError.MissingConfigError(missingConfig: "missing weightOfValues in parser informations")
        }
        guard start != nil else {
            throw ConfigError.MissingConfigError(missingConfig: "missing startSeparator in parser informations")
        }
        guard end != nil else {
            throw ConfigError.MissingConfigError(missingConfig: "missing endSeparator in parser informations")
        }
        guard seps as? [String] != nil else {
            throw ConfigError.BadFormatError(in: "parser informations", info: "bad format of separatorsBetweenValues, should be \([String].self)")
        }
        guard weights as? [Int] != nil else {
            throw ConfigError.BadFormatError(in: "parser informations", info: "bad format of weightOfValues, should be \([Int].self)")
        }
        guard start as? String != nil else {
            throw ConfigError.BadFormatError(in: "parser informations", info: "bad format of startSeparator, should be \(String.self)")
        }
        guard end as? String != nil else {
            throw ConfigError.BadFormatError(in: "parser informations", info: "bad format of endSeparator, should be \(String.self)")
        }
            return try MultidimensionalPointParser.init(separatorsBetweenValues: seps as! [String], weightOfValues: weights as! [Int], startSeparator: start as! String, endSeparator: end as! String)
    }
    
    private func getRules(intervals:[[String:Any]]) throws -> [Rule]{
        var res:[Rule] = []
        for elem in intervals{
            if let val = elem["value"]{
                let value = val as! String

                guard elem["lowerInterval"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "lowerInterval in ruledTaxonomies")}
                guard elem["upperInterval"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "upperInterval in ruledTaxonomies")}
                guard elem["lowerInclusion"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "lowerInclusion in ruledTaxonomies")}
                guard elem["upperInclusion"] != nil else {throw ConfigError.MissingConfigError(missingConfig: "upperInclusion in ruledTaxonomies")}

                guard elem["upperInterval"] as? [String] != nil else {throw ConfigError.BadFormatError(in: "ruledTax",info:"bad format of upperInterval type, should be \([String].self)")}
                guard elem["lowerInterval"] as? [String] != nil else {throw ConfigError.BadFormatError(in: "ruledTax", info: "bad format of lowerInterval type, should be \([String].self)")}
                guard elem["upperInclusion"] as? [String] != nil else {throw ConfigError.BadFormatError(in: "ruledTax", info: "bad format of upperInclusion, should be \([String].self)")}
                guard elem["lowerInclusion"] as? [String] != nil else {throw ConfigError.BadFormatError(in: "ruledTax", info: "bad format of lowerInclusion type, should be \([String].self)")}
                
                let uinterval = elem["upperInterval"] as! [String]
                let dinterval = elem["lowerInterval"] as! [String]
                let uinclusion = elem["upperInclusion"] as! [String]
                let dinclusion = elem["lowerInclusion"] as! [String]
                
                res.append(try Rule.init(value: value, upperLimits: uinterval, lowerLimits: dinterval, upperInclusions: uinclusion, lowerInclusions: dinclusion))
            }else{
                throw ConfigError.MissingConfigError(missingConfig: "missing value in ruledTaxonomies")
            }
        }
        return res
    }
}

struct JSONConfig {
    
    let file:File
    
    public init(pathOfConfigurationFile path:String) throws {
        
        self.file = File(path)
        if self.file.exists == false {
            throw ConfigError.FileDoesNotExist(file:path)
        }
    }
    
    public func getValues() throws -> Dictionary<String, Any>{
        try file.open(.read, permissions: .readUser)
        defer { file.close() }
        let txt:String
        do {
            txt = try file.readString()
        } catch {
            throw ConfigError.IOError(alert:"An Input/Output error occured while reading the configuration file:" + self.file.path)
        }
        do{
            let dict = try txt.jsonDecode() as! Dictionary<String, Any>
            return dict
        }catch{
            throw ConfigError.JSONDecodeError(alert:"The JSON in the configuration file: " + file.path + " is unparsable!")
        }
    }
}
