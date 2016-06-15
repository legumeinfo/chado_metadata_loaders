SELECT distinct p.project_id, p.name AS project, pp.value AS project_description,
       p_a.analysis_id, p_a.name AS assembly_name,
       p_a.description AS assembly_description, e.nd_experiment_id, 
       s.stock_id, s.name AS stock_name
FROM project p
  INNER JOIN
      (SELECT pa.project_id, a.analysis_id, a.name, a.description, a.program
       FROM project_analysis pa
         INNER JOIN analysis a ON a.analysis_id=pa.analysis_id
         INNER JOIN analysisprop ap ON ap.analysis_id=a.analysis_id
         INNER JOIN cvterm apt ON apt.cvterm_id=ap.type_id
       WHERE ap.value='Genome assembly' AND apt.name='analysis_type'
      ) p_a ON p_a.project_id=p.project_id
  INNER JOIN projectprop pp 
    ON pp.project_id=p.project_id
       AND pp.type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='project_description'
                             AND cv_id=(SELECT cv_id FROM cv 
                                        WHERE name='genome_metadata_structure'))
  INNER JOIN nd_experiment_project ep ON ep.project_id=p.project_id
  INNER JOIN nd_experiment e ON e.nd_experiment_id=ep.nd_experiment_id
  INNER JOIN nd_experiment_stock es ON es.nd_experiment_id=e.nd_experiment_id
  INNER JOIN stock s ON s.stock_id=es.stock_id
;




