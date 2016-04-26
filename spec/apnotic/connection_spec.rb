require 'spec_helper'

describe Apnotic::Connection do
  let(:uri) { nil }
  let(:cert_path) { cert_file_path }
  let(:connection) do
    Apnotic::Connection.new({
      uri:       uri,
      cert_path: cert_path,
      cert_pass: ""
    })
  end

  describe ".new" do

    describe "option: uri" do

      subject { connection.uri }

      context "when uri is not set" do
        let(:uri) { nil }

        it "defaults to APPLE PRODUCTION uri" do
          expect(subject).to be_a URI::HTTPS

          expect(subject.scheme).to eq "https"
          expect(subject.host).to eq "api.push.apple.com"
          expect(subject.port).to eq 443
        end
      end

      context "when uri is set" do

        context "and it is a secure address" do
          let(:uri) { "https://localhost:4343" }

          it "sets it" do
            expect(subject).to be_a URI::HTTPS

            expect(subject.scheme).to eq "https"
            expect(subject.host).to eq "localhost"
            expect(subject.port).to eq 4343
          end
        end

        context "and it is not a secure address" do
          let(:uri) { "http://localhost:4343" }

          it "raises an error" do
            expect { connection }.to raise_error "URI needs to be a HTTPS address"
          end
        end
      end
    end

    describe "option: cert_path" do

      subject { connection.cert_path }

      context "when it points to an existing file" do
        let(:cert_path) { cert_file_path }

        it "sets it" do
          expect(subject).to eq cert_path
        end
      end

      context "when it points to an non-existant file" do
        let(:cert_path) { "/non-existant.crt" }

        it "raises an error" do
          expect { connection }.to raise_error "Cert file not found: /non-existant.crt"
        end
      end
    end
  end

  describe ".development" do
    let(:options) { { uri: "will-be-overwritten", other: "options" } }

    it "initializes a connection object with uri set to APPLE DEVELOPMENT" do
      expect(Apnotic::Connection).to receive(:new).with(options.merge({
        uri: "https://api.development.push.apple.com:443"
      }))

      Apnotic::Connection.development(options)
    end
  end

  describe "#build_headers_for" do
    let(:notification_body) { "notification-body" }
    let(:notification) do
      notification            = Apnotic::Notification.new("phone-token")
      notification.id         = "apns-id"
      notification.expiration = 1461491082
      notification.priority   = 10
      notification.topic      = "com.example.myapp"
      notification
    end

    def build_headers
      connection.send(:build_headers_for, notification)
    end

    before { allow(notification).to receive(:body) { notification_body } }

    it "returns the headers hash" do
      expect(build_headers).to eq ({
        ":scheme"         => "https",
        ":method"         => "POST",
        ":path"           => "/3/device/phone-token",
        "host"            => "api.push.apple.com",
        "content-length"  => "17",
        "apns-id"         => "apns-id",
        "apns-expiration" => 1461491082,
        "apns-priority"   => 10,
        "apns-topic"      => "com.example.myapp"
      })
    end
  end

  describe "#push" do
    let(:notification) { double(:notification, token: "token", body: "notification-body") }
    let(:headers) { double(:headers) }
    let(:h2_stream) { double(:h2_stream) }
    let(:stream) { double(:stream, h2_stream: h2_stream) }
    let(:options) { double(:options) }
    let(:response) { double(:response) }

    before do
      allow(connection).to receive(:build_headers_for).with(notification) { headers }
      allow(connection).to receive(:new_stream) { stream }
      allow(stream).to receive(:response).with(options) { response }
    end

    it "sends the stream with the correct headers & data" do
      expect(h2_stream).to receive(:headers).with(headers, { end_stream: false })
      expect(h2_stream).to receive(:data).with("notification-body", { end_stream: true })

      result = connection.push(notification, options)
      expect(result).to eq response
    end
  end
end
