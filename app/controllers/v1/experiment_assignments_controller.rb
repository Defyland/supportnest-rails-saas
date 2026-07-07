module V1
  class ExperimentAssignmentsController < ApplicationController
    def create
      authorize!(:experiments_assign)

      assignment = Experiments::Assign.call!(
        organization: current_organization,
        experiment_key: params[:experiment_key],
        subject_key: assignment_subject_key,
        context: assignment_params[:context]&.to_h
      )

      render json: { assignment: assignment.as_api_json }, status: :created
    end

    private

    def assignment_params
      params.require(:assignment).permit(:subject_key, context: {})
    end

    def assignment_subject_key
      assignment_params.require(:subject_key)
    end
  end
end
