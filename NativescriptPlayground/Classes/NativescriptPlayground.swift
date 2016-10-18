//
//  Created by Rob Laverty on 10/6/16.
//

import Foundation
import Contacts
import SwiftyJSON
import Bolts
import FMDB



public typealias OtherContactsHandler = (_ contacts : [CNContact] , _ error : NSError?) -> Void
public typealias recognizeHandler = (_ error : NSError?) -> Void

//public struct SQLiteStatement {
//	var query: String
//	var values: [String]
//}

@objc open class BoltThreads: NSObject {
    
	var contactsStore: CNContactStore?
	
	open func selectionContactKeys() -> [CNKeyDescriptor] {
		return [CNContactNamePrefixKey as CNKeyDescriptor,
		        CNContactGivenNameKey as CNKeyDescriptor,
		        CNContactFamilyNameKey as CNKeyDescriptor,
		        CNContactOrganizationNameKey as CNKeyDescriptor,
		        CNContactBirthdayKey as CNKeyDescriptor,
		        CNContactImageDataKey as CNKeyDescriptor,
		        CNContactThumbnailImageDataKey as CNKeyDescriptor,
		        CNContactImageDataAvailableKey as CNKeyDescriptor,
		        CNContactPhoneNumbersKey as CNKeyDescriptor,
		        CNContactEmailAddressesKey as CNKeyDescriptor,
		]
	}
	
	open func getAllContactsAsync() -> BFTask<AnyObject> {
		if (contactsStore == nil) {
			contactsStore = CNContactStore()
		}
		let task = BFTaskCompletionSource<AnyObject>()
		DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
			var contactsArray = Array<CNContact>()
			let contactFetchRequest = CNContactFetchRequest(keysToFetch: self.selectionContactKeys())
			do {
				try self.contactsStore?.enumerateContacts(with: contactFetchRequest, usingBlock: { (contact, stop) -> Void in
					if contact.phoneNumbers.count > 0 {
						contactsArray.append(contact)
					}
				})
			} catch let error as NSError {
				print(error.localizedDescription)
				task.setError(error)
			}
			DispatchQueue.main.async(execute: { () -> Void in
				task.setResult(contactsArray as AnyObject?)
			})
		})
		return task.task
	}
	
	open func getContactByIdAsync(Id: String) -> BFTask<CNContact> {
		if (contactsStore == nil) {
			contactsStore = CNContactStore()
		}
		let task = BFTaskCompletionSource<CNContact>()
		DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
			var result: CNContact? = nil
			do {
				result = try self.contactsStore?.unifiedContact(withIdentifier: Id, keysToFetch: self.selectionContactKeys())
			} catch let error as NSError {
				print(error.localizedDescription)
				task.setError(error)
			}
			DispatchQueue.main.async(execute: { () -> Void in
				task.setResult(result as CNContact?)
			})
		})
		
		return task.task
	}
	
	open func getContactsByNameAsync(Name: String) -> BFTask<AnyObject> {
		if (contactsStore == nil) {
			contactsStore = CNContactStore()
		}
		let task = BFTaskCompletionSource<AnyObject>()
		DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
			var result: Array<CNContact>? = nil
			do {
				let predicate = CNContact.predicateForContacts(matchingName: Name)
				result = try self.contactsStore?.unifiedContacts(matching: predicate, keysToFetch: self.selectionContactKeys())
			} catch let error as NSError {
				print(error.localizedDescription)
				task.setError(error)
			}
			DispatchQueue.main.async(execute: { () -> Void in
				task.setResult(result as AnyObject?)
			})
		})
		return task.task
	}
	
	
	
	
	
	open func sqlWriteAsync(Path: String, Statements: String, Version: Int) -> BFTask<AnyObject> {
		let task = BFTaskCompletionSource<AnyObject>()
		let statements: [JSON] = JSON.parse(Statements).array!
		let queue: FMDatabaseQueue = FMDatabaseQueue.init(path: Path)
		queue.inTransaction { db, rollback in
			do {
				db?.setUserVersion(UInt32(Version))
				for statement in statements {
					try db?.executeUpdate(statement["query"].stringValue, values: statement["values"].array!)
				}
				task.setResult(true as AnyObject?)
			} catch let error as NSError {
				print(error.localizedDescription)
				task.setError(error)
				//				rollback.memory = true
			}
		}
		return task.task
	}
	
	open func sqlReadAsync(Path: String, Statements: String, Version: Int) -> BFTask<AnyObject> {
		let task = BFTaskCompletionSource<AnyObject>()
		let statements: [JSON] = JSON.parse(Statements).array!
		let queue: FMDatabaseQueue = FMDatabaseQueue.init(path: Path)
		queue.inTransaction { db, rollback in
			do {
				db?.setUserVersion(UInt32(Version))
				var results: Array<FMResultSet> = []
				for statement in statements {
					let result = try db?.executeQuery(statement["query"].stringValue, values: statement["values"].array!)
					results.append(result!)
				}
				task.setResult(results as AnyObject?)
			} catch let error as NSError {
				print(error.localizedDescription)
				task.setError(error)
				//				rollback.memory = true
			}
		}
		return task.task
	}
	
	
	
	
	
	//
	
	
	
	
	
    open func getContacts() {
        getContactsAsync( {(contacts, error) in
            if (error == nil) {
                print(contacts)
            }
        })
    }
	
    open func getContactsAsync(_ completion:  @escaping OtherContactsHandler) {
		
        if contactsStore == nil {
            contactsStore = CNContactStore()
        }
		
        getContactsOnBackgroundThread { (contactsArray) in
            completion(contactsArray, nil)
        }
    }
    
    open func getContactsOnBackgroundThread ( completion:@escaping (_ contacts:[CNContact])->()) {
        
        DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
            var contactsArray = [CNContact]()
            let contactFetchRequest = CNContactFetchRequest(keysToFetch: self.selectionContactKeys())
            
            do {
                try self.contactsStore?.enumerateContacts(with: contactFetchRequest, usingBlock: { (contact, stop) -> Void in
                    if contact.phoneNumbers.count > 0 {
                        contactsArray.append(contact)
                    }
                })
            } catch let error as NSError {
                print(error.localizedDescription)
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                completion(contactsArray)
            })
        })
    }
	
	open func getContactsBolts() -> [BFTask<CNContact>] {
		
		if contactsStore == nil {
			contactsStore = CNContactStore()
		}
		
		let task = BFTaskCompletionSource<AnyObject>()
		
		getContactsAsync( {(contacts: [CNContact], error) in
			if (error == nil) {
				task.setResult(contacts as [CNContact] as AnyObject?)
			} else {
				task.setError(error!)
			}
		})
		
		let sendi: AnyObject = task.task
		return sendi as! [BFTask<CNContact>]
	}
	
	
	
//    open func recognizeAsyncBolts(TESS: G8Tesseract) -> BFTask<AnyObject> {
//        let task = BFTaskCompletionSource<AnyObject>()
//        
//        recognizeOnBackgroundThread(TESS: TESS, completion: {() -> Void in
//            task.setResult(nil)
//        })
//        
//        let sendi: Any = task.task
//        return sendi as! BFTask<AnyObject>
//    }
//    
//    open func recognizeOnBackgroundThread ( TESS: G8Tesseract, completion:@escaping() -> Void) {
//        
//        DispatchQueue.global(qos: .userInitiated).async(execute: { () -> Void in
//            TESS.recognize()
//            DispatchQueue.main.async(execute: { () -> Void in
//                completion()
//            })
//        })
//    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
