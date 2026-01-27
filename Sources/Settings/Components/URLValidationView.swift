import SwiftUI

/// A view that displays URL validation status with appropriate icons and colors
struct URLValidationView: View {
    let validation: URLValidator.ValidationResult
    
    var body: some View {
        switch validation {
        case .valid:
            EmptyView()
            
        case .warning(let reason):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
        case .invalid(let reason):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// A text field with built-in URL validation
struct ValidatedURLField: View {
    let placeholder: String
    @Binding var url: String
    let validationType: URLValidationType
    @State private var validation: URLValidator.ValidationResult = .valid
    
    enum URLValidationType {
        case google
        case libreTranslate
        case llm
        case generic
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: url) { _, newValue in
                    validate(newValue)
                }
                .onAppear {
                    validate(url)
                }
            
            URLValidationView(validation: validation)
        }
    }
    
    private func validate(_ urlString: String) {
        let (sanitized, _) = URLValidator.validateAndSanitize(urlString)
        
        switch validationType {
        case .google:
            validation = URLValidator.validateGoogleApiUrl(sanitized)
        case .libreTranslate:
            validation = URLValidator.validateLibreTranslateUrl(sanitized)
        case .llm:
            validation = URLValidator.validateLLMApiUrl(sanitized)
        case .generic:
            validation = URLValidator.validate(sanitized)
        }
        
        // Update the URL if it was sanitized
        if sanitized != urlString && !sanitized.isEmpty {
            DispatchQueue.main.async {
                self.url = sanitized
            }
        }
    }
}

#Preview("URL Validation States") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Valid URL").font(.headline)
        URLValidationView(validation: .valid)
        
        Text("Warning").font(.headline)
        URLValidationView(validation: .warning(reason: "URL doesn't match known LLM API patterns"))
        
        Text("Invalid").font(.headline)
        URLValidationView(validation: .invalid(reason: "URL contains placeholder 'PROJECT_ID' - replace with actual value"))
    }
    .padding()
    .frame(width: 400)
}
