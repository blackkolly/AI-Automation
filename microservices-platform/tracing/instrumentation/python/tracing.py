# Python OpenTelemetry Instrumentation Example
# This file shows how to instrument a Python application with OpenTelemetry

import os
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.semconv.resource import ResourceAttributes
from flask import Flask, request, jsonify

# Configure the tracer
def configure_tracer():
    resource = Resource.create({
        ResourceAttributes.SERVICE_NAME: "payment-service",
        ResourceAttributes.SERVICE_VERSION: "1.0.0",
        ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
    })
    
    trace.set_tracer_provider(TracerProvider(resource=resource))
    
    jaeger_exporter = JaegerExporter(
        agent_host_name="jaeger-agent",
        agent_port=6831,
    )
    
    span_processor = BatchSpanProcessor(jaeger_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)

# Initialize tracing
configure_tracer()
tracer = trace.get_tracer(__name__)

# Create Flask app
app = Flask(__name__)

# Auto-instrument Flask
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
# SQLAlchemyInstrumentor().instrument(engine=db_engine)
# RedisInstrumentor().instrument()

@app.route('/payments', methods=['POST'])
def create_payment():
    """Create a new payment with distributed tracing"""
    with tracer.start_as_current_span("create_payment") as span:
        try:
            # Add custom attributes
            span.set_attribute("payment.amount", request.json.get('amount'))
            span.set_attribute("payment.currency", request.json.get('currency'))
            span.set_attribute("payment.method", request.json.get('method'))
            span.set_attribute("http.method", request.method)
            span.set_attribute("http.url", request.url)
            
            # Validate payment data
            payment_data = validate_payment(request.json)
            
            # Process payment
            payment_result = process_payment(payment_data)
            
            # Send notification
            send_notification(payment_result)
            
            span.set_attribute("payment.status", payment_result['status'])
            span.set_attribute("payment.id", payment_result['id'])
            
            return jsonify(payment_result), 201
            
        except ValueError as e:
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
            return jsonify({'error': str(e)}), 400
            
        except Exception as e:
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
            return jsonify({'error': 'Internal server error'}), 500

def validate_payment(data):
    """Validate payment data with tracing"""
    with tracer.start_as_current_span("validate_payment") as span:
        required_fields = ['amount', 'currency', 'method', 'card_number']
        
        for field in required_fields:
            if field not in data:
                span.add_event("validation_failed", {"missing_field": field})
                raise ValueError(f"Missing required field: {field}")
        
        if data['amount'] <= 0:
            span.add_event("validation_failed", {"reason": "invalid_amount"})
            raise ValueError("Amount must be positive")
        
        span.set_attribute("validation.status", "success")
        span.add_event("validation_completed")
        return data

def process_payment(payment_data):
    """Process payment with external service call"""
    with tracer.start_as_current_span("process_payment") as span:
        span.set_attribute("payment.processor", "stripe")
        
        # Simulate external API call
        with tracer.start_as_current_span("external_api_call") as api_span:
            api_span.set_attribute("http.method", "POST")
            api_span.set_attribute("http.url", "https://api.stripe.com/v1/charges")
            api_span.set_attribute("http.status_code", 200)
            
            # Simulate processing time
            import time
            time.sleep(0.1)
            
            result = {
                'id': 'pay_123456789',
                'status': 'success',
                'amount': payment_data['amount'],
                'currency': payment_data['currency']
            }
            
            api_span.set_attribute("payment.transaction_id", result['id'])
            
        span.set_attribute("payment.processing_time_ms", 100)
        return result

def send_notification(payment_result):
    """Send notification with tracing"""
    with tracer.start_as_current_span("send_notification") as span:
        span.set_attribute("notification.type", "email")
        span.set_attribute("notification.recipient", "user@example.com")
        
        # Simulate notification sending
        span.add_event("notification_sent", {
            "payment_id": payment_result['id'],
            "amount": payment_result['amount']
        })

@app.route('/health')
def health_check():
    """Health check endpoint with minimal tracing"""
    with tracer.start_as_current_span("health_check") as span:
        span.set_attribute("health.status", "healthy")
        return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

"""
Usage with manual span creation:

from opentelemetry import trace

tracer = trace.get_tracer(__name__)

def business_operation():
    with tracer.start_as_current_span("business_operation") as span:
        # Add custom attributes
        span.set_attribute("operation.type", "user_registration")
        span.set_attribute("user.id", "12345")
        
        # Add events
        span.add_event("validation_started")
        
        try:
            # Your business logic here
            result = perform_operation()
            
            span.add_event("operation_completed", {
                "result_count": len(result)
            })
            
            return result
            
        except Exception as e:
            # Record exception
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
            raise

# Context propagation example
def service_call_with_context():
    with tracer.start_as_current_span("service_call") as span:
        # Get current context
        ctx = trace.set_span_in_context(span)
        
        # Propagate context to child function
        child_operation_with_context(ctx)

def child_operation_with_context(context):
    with tracer.start_as_current_span("child_operation", context=context) as span:
        # This span will be a child of the parent span
        span.set_attribute("child.operation", "data_processing")
"""
