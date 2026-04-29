package com.example.myanimalz.repository;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.example.myanimalz.entity.Species;

@Repository
public interface SpeciesRepository extends CrudRepository<Species, Long> {
}
