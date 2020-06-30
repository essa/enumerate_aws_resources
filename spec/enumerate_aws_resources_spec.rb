require "spec_helper"
RSpec.describe EnumerateAwsResources do
  it "has a version number" do
    expect(EnumerateAwsResources::VERSION).not_to be nil
  end

  def sequence(name, number)
    (1...number+1).map do |i|
      name + i.to_s
    end
  end

  describe "#enumerate_service" do
    let(:cluster) { "my_cluster" }
    let(:aws_client) { double("aws_client") }
    subject { described_class.new(aws_client).enumerate_service(cluster: cluster) }
    let(:list_resp) { double "list_resp" }
    let(:describe_resp) { double "describe_resp"}
    let(:arns) { sequence("arn", 1) }
    let(:services) { sequence("service", 1)}

    before do
      allow(list_resp).to receive(:service_arns).and_return(arns)
      allow(list_resp).to receive(:next_token).and_return(nil)
      allow(aws_client).to receive(:list_services).and_return(list_resp)
      allow(describe_resp).to receive(:services).and_return(services)
      allow(aws_client).to receive(:describe_services).and_return(describe_resp)
    end

    it "should call list_services API" do
      expect(aws_client).to receive(:list_services).with({:cluster=>"my_cluster", :max_results=>100, :next_token=>nil})
      expect(subject.next).not_to be_nil
    end

    it "should call describe_services API" do
      expect(aws_client).to receive(:describe_services).with({:cluster=>"my_cluster", :services=>["arn1"]})
      expect(subject.next).not_to be_nil
    end

    context "with multiple services" do
      let(:arns) { sequence("arn", 3) }
      let(:services) { sequence("service", 3)}

      before do
        services.each_with_index do |s, i|
          expect(s).to receive(:service_name).and_return("service#{i+1}")
        end
      end

      it "should yield mutiple services" do
        expect(aws_client).to receive(:describe_services).with({:cluster=>"my_cluster", :services=>["arn1","arn2", "arn3"]})
        expect(subject.map(&:service_name)).to eq(["service1", "service2", "service3"])
      end

    end

    describe "options" do
      subject { described_class.new(aws_client, list_max: 3, describe_max: 2) }

      it "should accept max options" do
        expect(subject.instance_variable_get(:@list_max)).to eq(3)
        expect(subject.instance_variable_get(:@describe_max)).to eq(2)
      end
    end

    describe "minimum AWS API calls" do
      subject { described_class.new(aws_client, list_max: 3, describe_max: 2) }

      before do
        list_resp1 = double("list resp1")
        allow(list_resp1).to receive(:service_arns).and_return(sequence("arn", 3))
        allow(list_resp1).to receive(:next_token).and_return("token1")
        expect(aws_client).to receive(:list_services).with({:cluster=>"my_cluster", :max_results=>3, :next_token=>nil}).and_return(list_resp1).ordered

        describe_resp1 = double("describe resp1")
        allow(describe_resp1).to receive(:services).and_return([1, 2])
        expect(aws_client).to receive(:describe_services).with({:cluster=>"my_cluster", :services=>["arn1","arn2"]}).and_return(describe_resp1).ordered

        list_resp2 = double("list resp2")
        allow(list_resp2).to receive(:service_arns).and_return(sequence("arn", 2))
        allow(list_resp2).to receive(:next_token).and_return(nil)
        expect(aws_client).to receive(:list_services).with({:cluster=>"my_cluster", :max_results=>3, :next_token=>"token1"}).and_return(list_resp2).ordered

        describe_resp2 = double("describe resp2")
        allow(describe_resp2).to receive(:services).and_return([3, 4])
        expect(aws_client).to receive(:describe_services).with({:cluster=>"my_cluster", :services=>["arn3","arn1"]}).and_return(describe_resp2).ordered

        describe_resp3 = double("describe resp3")
        allow(describe_resp3).to receive(:services).and_return([5])
        expect(aws_client).to receive(:describe_services).with({:cluster => "my_cluster", :services=>["arn2"]}).and_return(describe_resp3).ordered
      end

      it "should invoke minimum AWS APIs" do
        expect(subject.enumerate_service(cluster: cluster).to_a).to eq([1, 2, 3, 4, 5])
      end
    end
  end
end
