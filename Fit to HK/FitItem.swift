//
//  FitItem.swift
//  Fit to HK
//
//  Created by Lars Klassen on 1/21/19.
//  Copyright © 2019 Lars Klassen. All rights reserved.
//

import Foundation

enum FitType {
    case heartRate, calories, distance
}

struct FitItem: Equatable, Comparable {
    var dateStart : Date;
    var dateEnd : Date;
    var value : Double;
    var type : FitType;
    
    static func == (lhs: FitItem, rhs: FitItem) -> Bool {
        if lhs.dateStart == rhs.dateStart && lhs.type == rhs.type {
            return true;
        } else {
            return false;
        }
    }
    
    static func < (lhs: FitItem, rhs: FitItem) -> Bool {
        return lhs.dateStart < rhs.dateStart;
    }
}
