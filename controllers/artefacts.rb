class ArtefactsController < ApplicationController

    namespace "/artefacts" do

        get do
            reply "for now we have only implemented 4 routes: /artefacts/:artefactID, /:artefactID/distributions, /:artefactID/distributions/:distributionID, /:artefactID/distributions/latest"
        end

        # Display one semantic artefact
        get "/:artefactID" do
            artefact = SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid `artefactID` to retrieve an artefact" if artefact.nil?
            check_last_modified(artefact)
            artefact.bring(*SemanticArtefact.goo_attrs_to_load(includes_param))
            reply artefact
        end

        # Display latest distribution
        get "/:artefactID/distributions/latest" do
            artefact = SemanticArtefact.find(params["artefactID"])
            error 404, "You must provide a valid artefactID to retrieve an artefact" if artefact.nil?
            artefact.bring(:distributions)
            include_status = params["include_status"] && !params["include_status"].empty? ? params["include_status"].to_sym : :any
            latest_distribution = artefact.latest_distribution(status: include_status)

            if latest_distribution
                check_last_modified(latest_distribution)
                latest_distribution.bring(*SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            end
            reply latest_distribution
        end

        # Display a distribution
        get '/:artefactID/distributions/:distributionID' do
            artefact = SemanticArtefact.find(params["artefactID"])
            error 422, "Semantic Artefact #{params["artefactID"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            artefact.bring(:distributions)
            artefact_distribution = artefact.distribution(params["distributionID"])
            error 404, "Distribuution with #{params['distributionID']} not found" if artefact_distribution.nil?
            artefact_distribution.bring(*SemanticArtefactDistribution.goo_attrs_to_load(includes_param))
            reply artefact_distribution
        end

        # Display a distribution
        get '/:artefactID/distributions' do
            artefact = SemanticArtefact.find(params["artefactID"])
            error 404, "Semantic Artefact #{params["acronym"]} does not exist" unless artefact
            check_last_modified_segment(LinkedData::Models::SemanticArtefactDistribution, [params["artefactID"]])
            artefact.bring(:distributions)
            # check_access(artefact.ontology)
            options = {
                status: (params["include_status"] || "ANY"),
                includes: SemanticArtefactDistribution.goo_attrs_to_load(includes_param)
            }
            distros = artefact.all_distributions(options)
            reply distros.sort {|a,b| b.distributionId.to_i <=> a.distributionId.to_i }
        end

        private

        # Method to render a collection of artefacts or a single artefact
        def render_artefacts(artefacts, mappings)
            artefacts = [artefacts] unless artefacts.is_a?(Array)
            reverse_mappings = mappings.invert

            rendered = artefacts.map do |artefact|
                loaded_attributes = artefact.instance_variable_get(:@loaded_attributes)
                
                artefact_data = loaded_attributes.each_with_object({}) do |attr, hash|
                    if artefact.respond_to?(attr)
                        value = artefact.public_send(attr)

                        if value.class == Array && !value.empty?
                            arr = []
                            value.each do |v|
                                if v.class.ancestors.include?(LinkedData::Hypermedia::Resource) && v.respond_to?(:id)
                                    arr << v.id.to_s
                                end 
                            end
                            value = arr
                        else
                            if value.class.ancestors.include?(LinkedData::Hypermedia::Resource) && value.respond_to?(:id)
                                value = value.id.to_s
                            end    
                        end

                        if reverse_mappings.key?(attr.to_s)
                            mapped_key = reverse_mappings[attr.to_s]
                            hash[mapped_key.to_sym] = value
                        else
                            hash[attr.to_sym] = value
                        end
                    else
                        hash[attr] = nil
                    end
                end

                artefact_data
            end
        
            # Return the rendered artefacts as JSON
            json rendered
        end


        def update_query_string!(env, mapping)
            existing_params = Rack::Utils.parse_nested_query(env["QUERY_STRING"])
          
            if existing_params["display"]
              display_params = existing_params["display"].split(",")          
              mapped_attributes = map_to_ontology_attributes(display_params)
              existing_params["display"] = mapped_attributes.join(",")
            end

            # Rebuild the query string and modify `env` in place
            env["QUERY_STRING"] = Rack::Utils.build_query(existing_params)
        end



        # Map artefacts attributes to ontology attributes using the mapping
        def map_to_ontology_attributes(attributes)
            mapping = artefacts_to_ontology
            attributes.map do |attr|
                (mapping[attr.to_s] || attr).to_sym
            end
        end

        def artefacts_to_ontology
            {
                "id" => "id",
                "type" => "ontologyType",
                "accessRights" => "viewingRestriction",
                "title" => "name",
                "acronym" => "acronym",
                "group" => "group",
                "hasEvaluation" => "reviews",
                "usedInProject" => "projects",
                "administeredBy" => "administeredBy"
            }
        end

        def map_to_submission_attributes(attributes)
            mapping = artefacts_to_submission

            attributes.map do |attr|
                (mapping[attr.to_s] || attr).to_sym
            end
        end

        def artefacts_to_submission
            {
                "creator" => "hasCreator",
                "conformsTo" => "conformsToKnowledgeRepresentationParadigm",
                "contactPoint" => "contact",
                "description" => "description",
                "identifier" => "identifier",
                "issued" => "released / creationDate",
                "keyword" => "keywords",
                "landingPage" => "documentation",
                "language" => "naturalLanguage",
                "license" => "hasLicense",
                "modified" => "modificationDate",
                "publisher" => "publisher",
                "relation" => "ontologyRelatedTo",
                "dcattheme" => "hasDomain",
                "type" => "isOfType",
                "competencyQuestion" => "competencyQuestion",
                "designedForTask" => "designedForOntologyTask",
                "endorsedBy" => "endorsedBy",
                "hasFormalityLevel" => "hasFormalityLevel",
                "knownUsage" => "knownUsage",
                "metrics" => "metrics",
                "semanticArtefactRelation" => "ontologyRelatedTo",
                "status" => "status / submissionStatus",
                "URI" => "URI",
                "administeredBy" => "administeredBy"
            }
        end


    end

end