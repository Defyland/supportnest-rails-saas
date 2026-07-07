module V1
  class ExperimentConversionsController < ApplicationController
    def create
      authorize!(:experiments_convert)

      conversion = Experiments::Convert.call!(
        organization: current_organization,
        experiment_key: params[:experiment_key],
        subject_key: conversion_params.require(:subject_key),
        event_name: conversion_params.require(:event_name),
        idempotency_key: conversion_params.require(:idempotency_key),
        metadata: conversion_params[:metadata]&.to_h
      )

      render json: { conversion: conversion.as_api_json }, status: :created
    end

    private

    def conversion_params
      params.require(:conversion).permit(:subject_key, :event_name, :idempotency_key, metadata: {})
    end
  end
end
