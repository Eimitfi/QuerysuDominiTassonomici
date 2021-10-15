//
//  Templates.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 23/08/2021.
//

import Foundation

struct StaticArbitraryTemplate:StaticTemplate, StaticTemplateReader{
    let query:String
    public init(query:String){
        self.query = query
    }
    func getQuery() -> String {
        return self.query
    }
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> StaticTemplate? {
        if let template = dict["template"]{
            if template == "staticArbitrary"{
                let q = dict["query"]! as String
                return StaticArbitraryTemplate.init(query: q)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    
    }
}


struct FlatTemplate:StaticTemplate,StaticTemplateReader{
    let attribute:Attribute
    let table:TableName
    var query:String
    public init(attribute:Attribute,table:TableName){
        self.attribute = attribute
        self.table = table
        self.query = "select distinct \(self.attribute) from \(self.table);"
    }
    func getQuery() -> String {
        return self.query
    }
    
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> StaticTemplate? {
        if let template = dict["template"]{
            if template == "flatTemplate"{
                return FlatTemplate.init(attribute: dict["attribute"]!, table: dict["table"]!)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    }
    
}

struct DynamicArbitraryTemplate:DynamicTemplate, DynamicTemplateReader{
    let beforeLeafInsertionPart:String
    let afterLeafInsertionPart:String
    public init(beforeLeafInsertionPart:String,afterLeafInsertionPart:String){
        self.beforeLeafInsertionPart = beforeLeafInsertionPart
        self.afterLeafInsertionPart = afterLeafInsertionPart
    }
    
    func getQuery(leaf: String) -> String {
        return self.beforeLeafInsertionPart + "'"+leaf+"'" + self.afterLeafInsertionPart
    }
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> DynamicTemplate? {
        if let template = dict["template"]{
            if template == "dynamicArbitrary"{
                return DynamicArbitraryTemplate.init(beforeLeafInsertionPart: dict["beforeLeafPart"]!, afterLeafInsertionPart: dict["afterLeafPart"]!)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    
    }
    
}

struct CommonChildrenArbitraryTemplate:CommonChildrenTemplate,CommonChildrenTemplateReader{
    let beforeFathersPart:String
    let afterFathersPart:String
    public init(beforeFathersPart:String,afterFathersPart:String){
        self.beforeFathersPart = beforeFathersPart
        self.afterFathersPart = afterFathersPart
    }
    
    func getQuery(nodes: Set<String>) -> String {
        let baseTuple = "('" + Array(nodes).joined(separator: "','") + "')"
        return self.beforeFathersPart + baseTuple + self.afterFathersPart
    }
    
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> CommonChildrenTemplate? {
        if let template = dict["template"]{
            if template == "commonChildrenArbitrary"{
                return CommonChildrenArbitraryTemplate.init(beforeFathersPart: dict["beforeFathersPart"]!, afterFathersPart: dict["afterFathersPart"]!)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    
    }
    
}

struct SameTableTemplate:StaticTemplate,DynamicTemplate,CommonChildrenTemplate,StaticTemplateReader,DynamicTemplateReader,ResultTemplate{
    let moreSpecificAttribute:Attribute
    let moreGenericAttribute:Attribute
    let tableName:TableName
    let staticQuery:String
    
    public init(moreSpecificAttribute:Attribute,moreGenericAttribute:Attribute,tableName:TableName){
        self.moreSpecificAttribute = moreSpecificAttribute
        self.moreGenericAttribute = moreGenericAttribute
        self.tableName = tableName
        self.staticQuery = "select distinct \(self.moreSpecificAttribute),\(self.moreGenericAttribute) from \(self.tableName);"
    }
    
    func getQuery() -> String {
        return self.staticQuery
    }
    
    func getQuery(leaf: String) -> String {
        return "select distinct \(self.moreSpecificAttribute),\(self.moreGenericAttribute) from \(self.tableName) where \(self.moreSpecificAttribute) = '\(leaf)';"
    }
    
    func getQuery(nodes: Set<String>) -> String {
        let baseTuple = "('" + Array(nodes).joined(separator: "','") + "')"
        return "select distinct \(self.moreSpecificAttribute) as moreSpecific, \(self.moreGenericAttribute) as moreGeneric from \(self.tableName) where \(self.moreGenericAttribute) in \(baseTuple)"
    }
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> StaticTemplate? {
        let read:DynamicTemplate? = try self.fromRawToTemplate(rawTemplate: dict)
        return read as! StaticTemplate?
    }
    
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> DynamicTemplate? {
        if let template = dict["template"]{
            if template == "sameTable"{
                return SameTableTemplate.init(moreSpecificAttribute: dict["moreSpecific"]!, moreGenericAttribute: dict["moreGeneric"]!, tableName: dict["table"]!)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    }
    
    public func getQuery(staticNode: String) -> String {
        return "select distinct \(self.moreSpecificAttribute) from \(self.tableName) where \(self.moreGenericAttribute) = '\(staticNode)';"
    }
    
}

struct JoinTemplate:StaticTemplate,DynamicTemplate,CommonChildrenTemplate,StaticTemplateReader,DynamicTemplateReader,ResultTemplate{
    let moreSpecificAttribute:Attribute
    let moreGenericAttribute:Attribute
    let moreSpecificTable:TableName
    let moreGenericTable:TableName
    let moreSpecificJoinAttribute:Attribute
    let moreGenericJoinAttribute:Attribute
    let staticQuery:String
    
    public init(moreSpecificAttribute:Attribute,moreGenericAttribute:Attribute,moreSpecificTable:TableName,moreGenericTable:TableName,moreSpecificJoinAttribute:Attribute,moreGenericJoinAttribute:Attribute){
        self.moreSpecificAttribute = moreSpecificAttribute
        self.moreGenericAttribute = moreGenericAttribute
        self.moreSpecificTable = moreSpecificTable
        self.moreGenericTable = moreGenericTable
        self.moreSpecificJoinAttribute = moreSpecificJoinAttribute
        self.moreGenericJoinAttribute = moreGenericJoinAttribute
        self.staticQuery = "select distinct T1.\(self.moreSpecificAttribute),T2.\(self.moreGenericAttribute) from \(self.moreSpecificTable) T1 join \(self.moreGenericTable) T2 on T1.\(self.moreSpecificJoinAttribute) = T2.\(self.moreGenericJoinAttribute);"
    }
    
    func getQuery() -> String {
        return self.staticQuery
    }
    
    func getQuery(leaf: String) -> String {
        return "select distinct T1.\(self.moreSpecificAttribute),T2.\(self.moreGenericAttribute) from \(self.moreSpecificTable) T1 join \(self.moreGenericTable) T2 on T1.\(self.moreSpecificJoinAttribute) = T2.\(self.moreGenericJoinAttribute) where T1.\(self.moreSpecificAttribute) = '\(leaf)';"
    }
    
    func getQuery(nodes: Set<String>) -> String {
        let baseTuple = "('" + Array(nodes).joined(separator: "','") + "')"
        return "select distinct T1.\(self.moreSpecificAttribute) as moreSpecific,T2.\(self.moreGenericAttribute) as moreGeneric from \(self.moreSpecificTable) T1 join \(self.moreGenericTable) T2 on T1.\(self.moreSpecificJoinAttribute) = T2.\(self.moreGenericJoinAttribute) where \(self.moreGenericAttribute) in \(baseTuple)"
    }
    
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> StaticTemplate? {
        let read:DynamicTemplate? = try self.fromRawToTemplate(rawTemplate: dict)
        return read as! StaticTemplate?
    }
    
    static func fromRawToTemplate(rawTemplate dict: Dictionary<String, String>) throws -> DynamicTemplate? {
        if let template = dict["template"]{
            if template == "join"{
                return JoinTemplate.init(moreSpecificAttribute: dict["moreSpecific"]!, moreGenericAttribute: dict["moreGeneric"]!, moreSpecificTable: dict["moreSpecificTable"]!, moreGenericTable: dict["moreGenericTable"]!, moreSpecificJoinAttribute: dict["moreSpecificJoinAttribute"]!, moreGenericJoinAttribute: dict["moreGenericJoinAttribute"]!)
            }else{
                return nil
            }
        }else{
            throw ConfigError.MissingConfigError(missingConfig: "missing template in \(dict)")
        }
    }
    
    public func getQuery(staticNode: String) -> String {
        return "select distinct T1.\(self.moreSpecificAttribute) from \(self.moreSpecificTable) T1 join \(self.moreGenericTable) T2 on T1.\(self.moreSpecificJoinAttribute) = T2.\(self.moreGenericJoinAttribute) where T2.\(self.moreGenericAttribute) = '\(staticNode)';"
    }
    
}
