//
//  Query.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 13/08/2021.
//

import Foundation

public struct StaticTaxonomyQuery{
    let template:StaticTemplate
    public init(template:StaticTemplate){
        self.template = template
    }
    public func getQuery() -> String{
        return self.template.getQuery()
    }
}

public struct DynamicTaxonomyQuery{
    let template:DynamicTemplate
    public init(template:DynamicTemplate){
        self.template = template
    }
    
    public func getQuery(leaf:String) -> String {
        return self.template.getQuery(leaf: leaf)
    }
}

public struct CommonChildrenTaxonomyQuery{
    let templates:[CommonChildrenTemplate]
    init(templates:[CommonChildrenTemplate]){
        self.templates = templates
    }
    
    public func getQuery(nodes: Set<String>) -> String {
        var tmpTabArr:[String] = []
        for elem in self.templates{
            tmpTabArr.append(elem.getQuery(nodes: nodes))
        }
        tmpTabArr.sort()
        var baseTab = tmpTabArr.joined(separator: " union ")
        baseTab = "(" + baseTab + ")"
        return "select count(*) from \(baseTab) T, \(baseTab) T1 where T1.moreSpecific = T.moreSpecific and T.moreGeneric <> T1.moreGeneric;"
    }
}



public protocol StaticTemplate{
    //voglio che ritorni le coppie figlio padre o solo attributo (nel caso in cui la tassonomia sia flat e la parte statica e' composta da un solo livello) della parte statica
    func getQuery() -> String
}

public protocol DynamicTemplate{
    //voglio query che ritorni le coppie figlio padre (figlio ridondante, e' leaf) con figlio uguale a leaf
    func getQuery(leaf:String) -> String
}

public protocol CommonChildrenTemplate{
    //voglio query che ritorni le coppie figlio padre in cui il padre faccia parte dell'insieme di nodi
    func getQuery(nodes:Set<String>) -> String
}

public protocol StaticTemplateReader{
    static func fromRawToTemplate(rawTemplate:Dictionary<String,String>) throws -> StaticTemplate?
}

public protocol DynamicTemplateReader{
    static func fromRawToTemplate(rawTemplate:Dictionary<String,String>) throws -> DynamicTemplate?
}

public protocol CommonChildrenTemplateReader{
    static func fromRawToTemplate(rawTemplate:Dictionary<String,String>) throws -> CommonChildrenTemplate?
}

public typealias TableName = String
