//
//  ViewController.swift
//  Fit to HK
//
//  Created by Lars Klassen on 1/21/19.
//  Copyright © 2019 Lars Klassen. All rights reserved.
//

import UIKit
import FitDataProtocol
import HealthKit

class ViewController: UIViewController, UITableViewDataSource {
    
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var labelDuration: UILabel!
    @IBOutlet weak var labelCalories: UILabel!
    @IBOutlet weak var labelDistance: UILabel!
    @IBOutlet weak var labelType: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var startDate : Date?;
    var duration : Double?;
    var calories : Double?;
    var distance : Double?;
    var isIndoor = false;
    var fitItems = [FitItem]();
    
    let dateFormatterFull = DateFormatter();
    let dateFormatterShort = DateFormatter();
    
    let healthStore = HKHealthStore();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.dateFormatterFull.dateFormat = "EEEE, dd MMM yyyy - HH:mm:ss";
        self.dateFormatterShort.dateFormat = "HH:mm:ss";
        
        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
                            HKObjectType.quantityType(forIdentifier: .heartRate)!]);
        
        healthStore.requestAuthorization(toShare: allTypes, read: nil) { (success, error) in
            
        }
        
        //let fitFileURL = Bundle.main.url(forResource: "2018-10-10-07-32-50", withExtension: "fit")!;
        //self.processFitFile(filePath: fitFileURL);
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fitItems.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell;
        let item = self.fitItems[indexPath.row];
        if item.type == .calories {
            cell.labelType.text = "Active Energy";
            cell.labelDate.text = self.dateFormatterShort.string(from: item.dateStart) + " -> " + self.dateFormatterShort.string(from: item.dateEnd);
        } else if item.type == .heartRate {
            cell.labelType.text = "Heart Rate";
            cell.labelDate.text = self.dateFormatterShort.string(from: item.dateStart);
        }
        cell.labelValue.text = String(item.value);
        
        return cell;
    }
    
    @IBAction func actionExport(_ sender: Any) {
        guard let startDate = self.startDate else {
            return;
        }
        guard let duration = self.duration else {
            return;
        }
        guard let calories = self.calories else {
            return;
        }
        
        let distance = self.distance ?? 0.0;
        let endDate = Date(timeInterval: TimeInterval(duration), since: startDate);
        
        let hkEnergyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories);
        let hkDistance = HKQuantity(unit: HKUnit.meter(), doubleValue: distance);
        
        let metadata = [HKMetadataKeyIndoorWorkout: self.isIndoor];
        let workout = HKWorkout(activityType: HKWorkoutActivityType.cycling,
                                start: startDate, end: endDate, duration: TimeInterval(duration),
                                totalEnergyBurned: hkEnergyBurned, totalDistance: hkDistance, metadata: metadata);
        
        healthStore.save(workout) { (success, error) in
            if success {
                var samples: [HKQuantitySample] = [];
                guard let distanceType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling) else {
                    return;
                }
                
                let distancePerIntervalSample = HKQuantitySample(type: distanceType, quantity: hkDistance, start: startDate, end: endDate);
                
                samples.append(distancePerIntervalSample);
                
                guard let energyBurnedType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned) else {
                    return;
                }
                
                let energyBurnedPerIntervalSample = HKQuantitySample(type: energyBurnedType, quantity: hkEnergyBurned,
                                                                     start: startDate, end: endDate);
                samples.append(energyBurnedPerIntervalSample);
                
                guard let heartRateType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
                    return;
                }
                
                for fitItem in self.fitItems {
                    if fitItem.type == .heartRate {
                        let heartRateForInterval = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: fitItem.value);
                        let heartRateForIntervalSample = HKQuantitySample(type: heartRateType, quantity: heartRateForInterval,
                                                                          start: fitItem.dateStart, end: fitItem.dateEnd,
                                                                          metadata: [HKMetadataKeyHeartRateMotionContext: NSNumber(value: HKHeartRateMotionContext.active.rawValue)]);
                        samples.append(heartRateForIntervalSample);
                    }
                }
                
                self.healthStore.add(samples, to: workout, completion: { (success, error) in
                    DispatchQueue.main.async {
                        if success {
                            self.startDate = nil;
                            self.duration = nil;
                            self.calories = nil;
                            self.distance = nil;
                            self.isIndoor = false;
                            self.fitItems.removeAll();
                            
                            self.labelDate.text = "";
                            self.labelDuration.text = "";
                            self.labelCalories.text = "";
                            self.labelDistance.text = "";
                            self.labelType.text = "";
                            self.tableView.reloadData();
                            
                            let alert = UIAlertController(title: "Complete", message: "Successfuly added workout", preferredStyle: .alert);
                            let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
                                alert.dismiss(animated: true, completion: nil);
                            }
                            alert.addAction(okAction);
                            self.present(alert, animated: true);
                        } else {
                            let errorMessage = error?.localizedDescription ?? "";
                            self.showErrorDialog(error: "Saved workout but not samples: " + errorMessage);
                        }
                    }
                })
                
            } else {
                DispatchQueue.main.async {
                    let errorMessage = error?.localizedDescription ?? "";
                    self.showErrorDialog(error: "Unable to save workout: " + errorMessage);
                }
            }
        }
    }
    
    func showErrorDialog(error : String) {
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert);
        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
            alert.dismiss(animated: true, completion: nil);
        }
        alert.addAction(okAction);
        self.present(alert, animated: true);
    }
    
    func processFitFile(filePath : URL) {
        if let fitFileData = try? Data(contentsOf: filePath) {
            self.fitItems.removeAll();
            self.tableView.reloadData();
            
            var decoder = FitFileDecoder(crcCheckingStrategy: .throws);
            
            var hrLowest = FitItem(dateStart: Date(), dateEnd: Date(), value: 1000000.0, type: .heartRate);
            var hrHighest = FitItem(dateStart: Date(), dateEnd: Date(), value: 0, type: .heartRate);
            var hrLastDate : Date?;
            var calSum = 0.0; //Data isn't used. Using total calories from SessionMessage is probably more reliable
            
            self.labelType.text = "Outdoor";
            self.isIndoor = false;
            
            do {
                try decoder.decode(data: fitFileData, messages: [DeviceInfoMessage.self, RecordMessage.self, LapMessage.self, SessionMessage.self]) { (fitMessage) in
                    
                    if let message = fitMessage as? DeviceInfoMessage, let manufacturer = message.manufacturer {
                        if manufacturer.name == "Zwift" {
                            self.labelType.text = "Indoor";
                            self.isIndoor = true;
                        }
                    } else if let message = fitMessage as? SessionMessage {
                        if let startTime = message.startTime, let startDate = startTime.recordDate {
                            self.startDate = startDate;
                            self.labelDate.text = self.dateFormatterFull.string(from: startDate);
                        }
                        
                        if let elapsedTime = message.totalElapsedTime {
                            self.duration = elapsedTime.value; //Seconds
                            
                            let hours = floor(elapsedTime.value / (60.0 * 60.0));
                            let minutes = floor((elapsedTime.value - (hours * (60.0 * 60.0))) / 60.0);
                            let seconds = elapsedTime.value - (hours * (60.0 * 60.0)) - (minutes * 60.0);
                            
                            self.labelDuration.text = String(format: "%02d:%02d:%02d", Int(hours), Int(minutes), Int(seconds));
                        }
                        if let calories = message.totalCalories {
                            self.calories = calories.value;
                            self.labelCalories.text = String(calories.value);
                        }
                        if let distance = message.totalDistance {
                            self.distance = distance.value; // meters
                            self.labelDistance.text = String(format: "%.2f Km", distance.value / 1000.0);
                        }
                        
                        //I assume that this is the last message;
                        if !self.fitItems.contains(hrLowest) {
                            self.fitItems += [hrLowest];
                        }
                        if !self.fitItems.contains(hrHighest) {
                            self.fitItems += [hrHighest];
                        }
                        self.fitItems.sort();
                        self.tableView.reloadData();
                    }
                    
                    if let message = fitMessage as? LapMessage {
                        if let startTime = message.startTime, let recordDate = startTime.recordDate, let calories = message.totalCalories, let elapsedTime = message.totalElapsedTime {
                            let endDate = Date(timeInterval: TimeInterval(elapsedTime.value), since: recordDate);
                            let fitItem = FitItem(dateStart: recordDate, dateEnd: endDate, value: calories.value, type: .calories);
                            self.fitItems += [fitItem];
                            self.fitItems.sort();
                            self.tableView.reloadData();
                            
                            calSum += calories.value;
                        }
                    }
                    
                    if let message = fitMessage as? RecordMessage {
                        if let timeStamp = message.timeStamp, let recordDate = timeStamp.recordDate, let heartRate = message.heartRate {
                            
                            if heartRate.value < 10.0 { //I would be dead?
                                return;
                            }
                            
                            let endDate = Date(timeInterval: TimeInterval(1), since: recordDate);
                            if heartRate.value < hrLowest.value {
                                hrLowest = FitItem(dateStart: recordDate, dateEnd: endDate, value: heartRate.value, type: .heartRate);
                            }
                            if heartRate.value > hrHighest.value {
                                hrHighest = FitItem(dateStart: recordDate, dateEnd: endDate, value: heartRate.value, type: .heartRate);
                            }
                            
                            if let date = hrLastDate {
                                if recordDate.timeIntervalSince(date) > 60.0 * 1 { //Record every minute hr
                                    hrLastDate = recordDate;
                                    let fitItem = FitItem(dateStart: recordDate, dateEnd: endDate, value: heartRate.value, type: .heartRate);
                                    self.fitItems += [fitItem];
                                }
                            } else {
                                hrLastDate = recordDate;
                                let fitItem = FitItem(dateStart: recordDate, dateEnd: endDate, value: heartRate.value, type: .heartRate);
                                self.fitItems += [fitItem];
                            }
                        }
                    }
                }
            } catch {
                self.showErrorDialog(error: "Unable to process Fit file");
            }
        }
    }
}

