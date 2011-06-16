class Sqlreports
  require 'savon' 
  require "base64"

  def self.print_report report_name, report_parameters
    file = nil
    begin
      Savon.configure do |config|
        config.log = true             # enable logging
        config.log_level = :info      # changing the log level
        config.logger = Rails.logger  # using the Rails logger
      end
      
      #Create the SOAP client to the SQL Server Report Execution Service with authentication
      client = Savon::Client.new do |wsdl, http|
        wsdl.document = "http://#{SQLREPORTS_CONFIG['server']}/reportserver/reportexecution2005.asmx?wsdl"
        
        if !SQLREPORTS_CONFIG['authorization'].nil?
          http.headers = { "Authorization" => SQLREPORTS_CONFIG['authorization'] }
        else
          http.headers = { "Authorization" => "Basic #{Base64.encode64 "#{SQLREPORTS_CONFIG['username']}:#{SQLREPORTS_CONFIG['password']}"}" }
        end
      end
      puts "Actions: #{client.wsdl.soap_actions}"
      
      puts SQLREPORTS_REPORTS[report_name]

      #Load the report
      response = client.request :soap, "load_report" do
        soap.input = ["LoadReport", { "xmlns" => "http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices" } ]        
        soap.body = { "Report" => SQLREPORTS_REPORTS[report_name] }
        soap.namespaces["xmlns:ExecutionHeader"] = "http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices"
      end
      execution_id = response.to_hash[:load_report_response][:execution_info][:execution_id]

      report_parameters_xml = ""
      report_parameters.each do |parameter|
        report_parameters_xml += "<ParameterValue><Name>#{parameter[:Name]}</Name><Value>#{parameter[:Value]}</Value></ParameterValue>"
      end

      #Set the Execution Parameters
      response = client.request "set_execution_parameters" do
        soap.xml = "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Header><ExecutionHeader xmlns=\"http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices\"><ExecutionID>#{execution_id}</ExecutionID></ExecutionHeader></soap:Header><soap:Body><SetExecutionParameters xmlns=\"http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices\"><Parameters>#{report_parameters_xml}</Parameters><ParameterLanguage>en-us</ParameterLanguage></SetExecutionParameters></soap:Body></soap:Envelope>"        
      end

      #Render the report
      response = client.request "render" do
        soap.xml = "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Header><ExecutionHeader xmlns=\"http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices\"><ExecutionID>#{execution_id}</ExecutionID></ExecutionHeader></soap:Header><soap:Body><Render xmlns=\"http://schemas.microsoft.com/sqlserver/2005/06/30/reporting/reportingservices\"><Format>PDF</Format></Render></soap:Body></soap:Envelope>"
      end

      file = Base64.decode64 response.to_hash[:render_response][:result]      

    rescue Savon::SOAP::Fault => fault
      puts "Fault"
      puts fault.to_s
    rescue Savon::Error => error
      puts "Error"
      puts error.to_s
    end

    return file      
  end
end

