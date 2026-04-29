package com.example.myanimalz.repository;

import java.util.List;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.example.myanimalz.entity.Animal;

@Repository
public interface AnimalRepository extends CrudRepository<Animal, Long> {

    List<Animal> findBySpeciesId(Long speciesId);
}
