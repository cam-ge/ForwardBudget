//
//  Forward_BudgetApp.swift
//  Forward Budget
//
//  Created by Camge98 on 2/26/25.
//

import SwiftUI
import Charts
import UserNotifications
import PDFKit
import Firebase

@main
struct Forward_BudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


struct Expense: Identifiable, Codable {
    let id = UUID()
    let category: String
    let amount: Double
    let date: Date
}

class BudgetViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    private let db = Firestore.firestore()

    init() {
        loadFromCloud()
    }
    
    func addExpense(category: String, amount: Double) {
        let newExpense = Expense(category: category, amount: amount, date: Date())
        expenses.append(newExpense)
        saveToCloud(expense: newExpense)
    }
    
    func filteredExpenses() -> [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenses.filter { expense in
            return calendar.isDate(expense.date, inSameDayAs: now)
        }
    }

    func totalSpent() -> Double {
        filteredExpenses().reduce(0) { $0 + $1.amount }
    }

    // MARK: - PDF Export
    func generatePDF() -> URL {
        let pdfFileName = FileManager.default.temporaryDirectory.appendingPathComponent("BudgetMate_Report.pdf")
        
        let pdfMetaData = [
            kCGPDFContextCreator: "BudgetMate",
            kCGPDFContextAuthor: "Your App"
        ]
        
        UIGraphicsBeginPDFContextToFile(pdfFileName.path, CGRect.zero, pdfMetaData)
        UIGraphicsBeginPDFPage()

        let context = UIGraphicsGetCurrentContext()
        let title = "Expense Report"
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)]
        title.draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
        
        var yOffset = 50
        for expense in filteredExpenses() {
            let text = "\(expense.category): $\(expense.amount, specifier: "%.2f")"
            text.draw(at: CGPoint(x: 20, y: CGFloat(yOffset)), withAttributes: nil)
            yOffset += 20
        }
        
        UIGraphicsEndPDFContext()
        return pdfFileName
    }

    // MARK: - Firebase Firestore Sync
    func saveToCloud(expense: Expense) {
        do {
            try db.collection("expenses").document(expense.id.uuidString).setData(from: expense)
        } catch {
            print("Error saving to Firestore: \(error.localizedDescription)")
        }
    }
    
    func loadFromCloud() {
        db.collection("expenses").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading from Firestore: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            self.expenses = documents.compactMap { try? $0.data(as: Expense.self) }
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = BudgetViewModel()
    @State private var showAddExpense = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationView {
            VStack {
                Text("Total Spent: $\(viewModel.totalSpent(), specifier: "%.2f")")
                    .font(.title)
                    .padding()
                
                List(viewModel.filteredExpenses()) { expense in
                    HStack {
                        Text(expense.category)
                        Spacer()
                        Text("$\(expense.amount, specifier: "%.2f")")
                    }
                }
                
                HStack {
                    Button("Add Expense") {
                        showAddExpense = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Menu("Export") {
                        Button("Export CSV") {
                            exportURL = viewModel.generateCSV()
                            showingShareSheet = true
                        }
                        Button("Export PDF") {
                            exportURL = viewModel.generatePDF()
                            showingShareSheet = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .sheet(isPresented: $showAddExpense) {
                    AddExpenseView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingShareSheet, content: {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                })
            }
            .navigationTitle("BudgetMate")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@main
struct BudgetMateApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
